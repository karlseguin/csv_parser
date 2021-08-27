defmodule CsvParser.Csv do
	@moduledoc false

	alias __MODULE__
	require Record

	Record.defrecord(:state, acc: nil, fun: nil, row: nil, headers: nil, map: nil)

	defstruct [:path, :lines, :opts]

	def new(path, opts) do
		opts = Keyword.put_new(opts, :strip_fields, true)
		{:ok, %Csv{path: path, opts: opts}}
	end

	def lines(lines, opts) do
		opts = Keyword.put_new(opts, :strip_fields, true)
		{:ok, %Csv{lines: lines, opts: opts}}
	end

	def reduce(%Csv{lines: nil} = csv, acc, fun) do
		csv.path
		|> File.stream!()
		|> CSV.decode(csv.opts)
		|> reduce(csv.opts, acc, fun)
	end

	def reduce(%Csv{} = csv, acc, fun) do
		csv.lines
		|> Stream.map(&(&1))
		|> CSV.decode(csv.opts)
		|> reduce(csv.opts, acc, fun)
	end

	def reduce(data, opts, acc, fun) do
		s = state(acc: acc, fun: fun, map: opts[:map] || false)
		s = Enum.reduce(data, s, &handle_row/2)
		state(s, :acc)
	end

	defp handle_row({:error, _} = err, s) do
		acc = state(s, :acc)
		acc = state(s, :fun).(err, acc)
		state(s, acc: acc)
	end

	defp handle_row({:ok, row}, s) do
		case fix_row(row) do
			:empty -> s
			ok -> handle_fixed_row(ok, s)
		end
	end

	# Used by memory parser
	defp handle_row(row, s) do
		case fix_row(row) do
			:empty -> s
			ok -> handle_fixed_row(ok, s)
		end
	end


	defp handle_fixed_row(row, s) when state(s, :map) == false do
		acc = state(s, :acc)
		acc = state(s, :fun).(row, acc)
		state(s, acc: acc)
	end

	defp handle_fixed_row({:ok, row}, s) when state(s, :headers) == nil do
		headers = case state(s, :map) do
			true -> row
			:upper -> Enum.map(row, &String.upcase/1)
			:lower -> Enum.map(row, &String.downcase/1)
			fun when is_function(fun) -> fun.(row)
		end
		state(s, headers: headers)
	end

	defp handle_fixed_row({:ok, row}, s) do
		headers = state(s, :headers)
		row = Map.new(Enum.zip(headers, row))

		acc = state(s, :acc)
		acc = state(s, :fun).({:ok, row}, acc)
		state(s, acc: acc)
	end

	defp fix_row(row) do
		res = Enum.reduce(row, {[], true}, fn
			"", {acc, empty?} -> {[nil | acc], empty?}
			value, {acc, _} -> {[value | acc], false}
		end)
		case res do
			{_, true} -> :empty
			{rows, false} -> {:ok, Enum.reverse(rows)}
		end
	end
end
