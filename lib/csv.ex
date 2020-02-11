defmodule CsvParser.Csv do
	@moduledoc false

	alias __MODULE__
	require Record

	Record.defrecord(:state, acc: nil, fun: nil, row: nil, headers: nil, map: nil)


	defstruct [:path, :opts]

	def new(path, opts) do
		opts = Keyword.put_new(opts, :strip_fields, true)
		{:ok, %Csv{path: path, opts: opts}}
	end

	def reduce(csv, acc, fun) do
		s = state(acc: acc, fun: fun, map: csv.opts[:map] || false)

		s = csv.path
		|> File.stream!()
		|> CSV.decode(csv.opts)
		|> Enum.reduce(s, &handle_row/2)

		state(s, :acc)
	end

	defp handle_row({:error, _} = err, s) do
		acc = state(s, :acc)
		acc = state(s, :fun).(err, acc)
		state(s, acc: acc)
	end

	defp handle_row(row, s) when state(s, :map) == false do
		acc = state(s, :acc)
		acc = state(s, :fun).(row, acc)
		state(s, acc: acc)
	end

	defp handle_row({:ok, row}, s) when state(s, :headers) == nil do
		headers = case state(s, :map) do
			true -> row
			:upper -> Enum.map(row, &String.upcase/1)
			:lower -> Enum.map(row, &String.downcase/1)
			fun when is_function(fun) -> fun.(row)
		end
		state(s, headers: headers)
	end

	defp handle_row({:ok, row}, s) do
		headers = state(s, :headers)
		row = Map.new(Enum.zip(headers, row))

		acc = state(s, :acc)
		acc = state(s, :fun).({:ok, row}, acc)
		state(s, acc: acc)
	end
end
