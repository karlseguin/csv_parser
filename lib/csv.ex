defmodule CsvParser.Csv do
	alias __MODULE__

	@moduledoc false

	defstruct [:path, :opts]

	def new(path, opts) do
		opts = Keyword.put_new(opts, :strip_fields, true)
		opts = case opts[:map] do
			true -> Keyword.put(opts, :headers, true)
			_ -> opts
		end

		{:ok, %Csv{path: path, opts: opts}}
	end

	def reduce(csv, acc, fun) do
		csv.path
		|> File.stream!()
		|> CSV.decode(csv.opts)
		|> Enum.reduce(acc, fun)
	end
end
