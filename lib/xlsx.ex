defmodule CsvParser.Xlsx do
	alias __MODULE__

	@moduledoc false

	defstruct [:sheet, :strings, :opts]

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
		suffix = case opts[:sheet_index] do
			nil -> nil
			index -> String.to_charlist("#{index}.xml")
		end

		Enum.find_value(xlsx, fn
			{[?x, ?l, ?/, ?w, ?o, ?r, ?k, ?s, ?h, ?e, ?e, ?t, ?s, ?/, ?s, ?h, ?e, ?e, ?t | rest], data} ->
				case suffix == nil || suffix == rest do
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
		{:ok, {acc, _, _, _}, _} =
		:erlsom.parse_sax(xlsx.sheet, {acc, nil, nil, false}, fn event, {acc, row, type, val?} ->
			case simplify(event) do
				{:startElement, 'row', _} -> {acc, [], nil, false}
				{:startElement, 'c', attr} -> {acc, row, get_attribute(attr, 't'), false}
				{:startElement, 'v', _} -> {acc, row, type, true}
				{:characters, value} ->
					case row != nil && type != nil && val? do
						true ->
							value = case type do
								's' -> elem(strings, elem(:string.to_integer(value), 0))
								_ -> String.Chars.to_string(value)
							end
							{acc, [value | row], true, true}
						false -> {acc, row, type, val?}
					end
				{:endElement, 'v'} -> {acc, row, type, false}
				{:endElement, 'c'} -> {acc, row, nil, false}
				{:endElement, 'row'} -> {fun.({:ok, Enum.reverse(row)}, acc), nil, nil, false}
				_ -> {acc, row, type, val?}
			end
		end)
		acc
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
