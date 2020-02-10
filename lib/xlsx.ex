defmodule CsvParser.Xlsx do
	alias __MODULE__
	require Record

	@moduledoc false

	defstruct [:sheet, :strings, :opts]

  Record.defrecord(:state, acc: nil, row: nil, type: nil, value: false, headers: nil)

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
		strings = xlsx.strings
		as_map? = xlsx.opts[:map] || false

		{:ok, s, _} = :erlsom.parse_sax(xlsx.sheet, state(acc: acc), fn event, s ->
			case simplify(event) do
				{:startElement, 'row', _} -> state(s, row: [], type: nil, value: false)
				{:startElement, 'c', attr} -> state(s, type: get_attribute(attr, 't'), value: false)
				{:startElement, 'v', _} -> state(s, value: true)
				{:characters, value} ->
					type = state(s, :type)
					case state(s, :row) == nil || type == nil|| state(s, :value) == false do
						true -> s  # a value that doesn't seem to belong to a row -> col -> value
						false ->
							value = case type do
								's' -> elem(strings, elem(:string.to_integer(value), 0))
								_ -> String.Chars.to_string(value)
							end
							state(s, row: [value | state(s, :row)])
					end
				{:endElement, 'v'} -> state(s, value: false)
				{:endElement, 'c'} -> state(s, type: nil, value: false)
				{:endElement, 'row'} ->
					row = Enum.reverse(state(s, :row))
					acc = case as_map? do
						true ->
							case state(s, :headers) do
								nil -> state(s, headers: row)
								headers ->
									row = Map.new(Enum.zip(headers, row))
									acc = fun.({:ok, row}, state(s, :acc))
									state(s, acc: acc, row: nil, type: nil, value: false)
							end
						false ->
							acc = fun.({:ok, row}, state(s, :acc))
							state(s, acc: acc, row: nil, type: nil, value: false)
					end
				_ -> s
			end
		end)
		state(s, :acc)
	end

	defp simplify({:startElement, _url, name, _prefix, attributes}), do: {:startElement, name, attributes}
	defp simplify({:endElement, _url, name, _prefix}), do: {:endElement, name}
	defp simplify(event), do: event

	defp get_attribute(attributes, type) do
		Enum.find_value(attributes, fn
			{:attribute, ^type, [], [], value} -> value
			_ -> nil
		end)
	end
end
