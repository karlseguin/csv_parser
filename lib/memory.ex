defmodule CsvParser.Memory do
	@moduledoc false

	alias __MODULE__
	defstruct [:data, :opts]

	def new(data, opts) do
		%Memory{data: data, opts: opts}
	end

	def reduce(m, acc, fun) do
		CsvParser.Csv.reduce(m.data, m.opts, acc, fun)
	end

end
