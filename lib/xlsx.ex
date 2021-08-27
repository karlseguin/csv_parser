defmodule CsvParser.Xlsx do
	@moduledoc false
	alias __MODULE__
	require Record

	defstruct [:sheet, :strings, :opts]

	Record.defrecord(:state, acc: nil, row: {nil, 0}, col: nil, value: false, headers: nil, strings: nil, map: nil, fun: nil, col_last: 0, col_count: nil)

	def new(path, opts) do
		with {:ok, xlsx} <- :zip.unzip(String.to_charlist(path), [:memory]),
				 {:ok, sheet} <- extract_sheet(xlsx, opts)
		do
			shared_string_data = Enum.find_value(xlsx, fn
				{'xl/sharedStrings.xml', data} -> data
				_ -> nil
			end)
			strings = parse_strings(shared_string_data)
			{:ok, %Xlsx{sheet: sheet, strings: strings, opts: opts}}
		else
			nil -> {:error, :unknown_sheet}
			_ -> {:error, :invalid_format}
		end
	end

	defp extract_sheet(xlsx, opts) do
		suffix = String.to_charlist("#{opts[:sheet_index] || 1}.xml")

		Enum.find_value(xlsx, fn
			{[?x, ?l, ?/, ?w, ?o, ?r, ?k, ?s, ?h, ?e, ?e, ?t, ?s, ?/, ?s, ?h, ?e, ?e, ?t | rest], data} ->
				case suffix == rest do
					true -> {:ok, data}
					false -> nil
				end
			_ -> nil
		end)
	end

	# not sure if this can happen, but no harm to handle it
	defp parse_strings(nil), do: {}

	defp parse_strings(data) do
		{:ok, {strings, _, _}, _} =
		:erlsom.parse_sax(data, {[], false, false}, fn event, {acc, item?, text?} ->
			case simplify(event) do
				{:startElement, 'si', _} -> {acc, true, false}
				{:startElement, 't', _} -> {acc, item?, true}
				{:characters, value} ->
					case item? && text? do
						true -> {[String.Chars.to_string(value) | acc], true, true}
						false -> {acc, item?, text?}
					end
				{:endElement, 't'} -> {acc, item?, false}
				{:endElement, 'si'} -> {acc, false, false}
				_ -> {acc, item?, text?}
			end
		end)

		strings
		|> Enum.reverse()
		|> List.to_tuple()
	end

	def reduce(xlsx, acc, fun) do
		s = state(acc: acc, fun: fun, strings: xlsx.strings, map: xlsx.opts[:map] || false)
		{:ok, s, _} = :erlsom.parse_sax(xlsx.sheet, s, fn event, s ->
			handle(simplify(event), s)
		end)
		state(s, :acc)
	end

	defp handle({:startElement, 'row', _}, s), do: state(s, row: {[], 0})
	defp handle({:startElement, 'c', attr}, s) do
		col = Enum.reduce(attr, {nil, nil}, fn
			{:attribute, 't', [], [], type}, {_type, index} -> {type, index}
			{:attribute, 'r', [], [], index}, {type, _index} -> {type, extract_index(index)}
			_, acc -> acc
		end)
		state(s, col: col, value: false)
	end

	defp handle({:startElement, 'v', _}, s), do: state(s, value: true)
	defp handle({:characters, value}, s) do
		{row, _} = state(s, :row)
		{type, index} = state(s, :col)
		case row == nil || type == nil|| state(s, :value) == false do
			true -> s # a value that doesn't seem to belong to a row -> col -> value
			false ->
				value = case type do
					's' -> elem(state(s, :strings), elem(:string.to_integer(value), 0))
					_ -> String.Chars.to_string(value)
				end

				last = state(s, :col_last)
				row = case index - last do
					1 -> row
					n -> append_missing(n, row)
				end
				state(s, row: {[value | row], index}, col_last: index)
		end
	end

	defp handle({:endElement, 'v'}, s), do: state(s, value: false)
	defp handle({:endElement, 'c'}, s), do: state(s, col: {nil, nil}, value: false)
	defp handle({:endElement, 'row'}, s) do
		{row, count} = state(s, :row)

		# right pad our row if count < col_count, or store col_count if this is the first row
		{s, row} = case state(s, :col_count) do
			nil -> {state(s, col_count: count), row}
			col_count ->
				row = case count < col_count do
					true -> Enum.reduce(count .. col_count - 1, row, fn _, row -> [nil | row] end)
					false -> row # we have a full column
				end
				{s, row}
		end

		row = Enum.reverse(row)
		case state(s, :map) do
			false ->
				acc = state(s, :fun).({:ok, row}, state(s, :acc))
				state(s, acc: acc, row: {nil, 0}, col: {nil, nil}, col_last: 0, value: false)
			transform ->
				case state(s, :headers) do
					nil -> state(s, headers: build_headers(transform, row), col: {nil, nil}, col_last: 0)
					headers ->
						row = Map.new(Enum.zip(headers, row))
						acc = state(s, :fun).({:ok, row}, state(s, :acc))
						state(s, acc: acc, row: {nil, 0}, col: {nil, nil}, col_last: 0, value: false)
				end
		end
	end

	defp handle(_other, s), do: s

	defp build_headers(true, row), do: row
	defp build_headers(:upper, row), do: Enum.map(row, &String.upcase/1)
	defp build_headers(:lower, row), do: Enum.map(row, &String.downcase/1)
	defp build_headers(fun, row) when is_function(fun), do: fun.(row)

	defp simplify({:startElement, _url, name, _prefix, attributes}), do: {:startElement, name, attributes}
	defp simplify({:endElement, _url, name, _prefix}), do: {:endElement, name}
	defp simplify(event), do: event

	defp extract_index([n1, r | _]) when r >= ?0 and r <= ?9 do
		n1 - ?A + 1
	end

	defp extract_index([n1, n2 | _]) do
		((n1 - ?A + 1) * 26) + n2 - ?A + 1
	end

	defp append_missing(2, row), do: [nil | row]
	defp append_missing(3, row), do: [nil | [nil | row]]
	defp append_missing(4, row), do: [nil | [nil | [nil | row]]]
	defp append_missing(5, row), do: [nil | [nil | [nil | [nil | row]]]]
	defp append_missing(n, row) do
		Enum.reduce(2..n, row, fn _, row -> [nil | row] end)
	end
end
