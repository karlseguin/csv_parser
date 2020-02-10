defmodule CsvParser do
	alias CsvParser.{Csv, Xlsx}

	@doc """
	Creates a new object to be passed into reduce!/3. new and reduce exist separately
	so that errors in your files can be handled explicitly.

	opts:
		type: :csv | :xlsx - defaults to nil, which will auto-detect
		map: bool - whether you want rows as a list or map (where the keys are taken from the first row)
		sheet_index: index (index) of the sheet to parse. Default to nil,
		             which will take the first sheet, only applicable to xlsx
	"""
	def new(path, opts \\ []) do
		opts = Keyword.put_new(opts, :validate_row_length, false)

		with {:ok, _} <- File.stat(path) do
			type = opts[:type]
			case type do
				:csv -> Csv.new(path, opts)
				:xlsx -> Xlsx.new(path, opts)
				nil ->
					case Xlsx.new(path, opts) do
						{:error, :invalid_format} -> Csv.new(path, opts)
						ok_or_error -> ok_or_error
					end
				_ -> {:error, :unknown_type}
			end
		end
	end

	@doc """
	Raises if path represents an invalid file
	"""
	def new!(path, opts \\ []) do
		case new(path, opts) do
			{:ok, obj} -> obj
			err -> raise err
		end
	end

	@doc """
	Reads the file returning a list of list. See new/2 for valid opts
	"""
	def read(path, opts \\ []) do
		with {:ok, obj} <- new(path, opts) do
			result = obj
			|> reduce!([], fn row, acc -> [row | acc] end)
			|> Enum.reverse()
			{:ok, result}
		end
	end

	@doc """
	Reads the file returning a list of list or raises on error
	"""
	def read!(path, opts \\ []) do
		case read(path, opts) do
			{:ok, data} -> data
			{:error, err} -> raise to_string(err)
		end
	end

	@doc """
	Reduces over the parsed file, calling fun/2 for each row.

	Example:
	csv = CsvParser.new!("sample.xlsx")
	rows = Enum.reduce(csv, [], fn {row, rows} -> [row | rows] end)
	"""
	def reduce!(%Csv{} = csv, acc, fun), do: Csv.reduce(csv, acc, fun)
	def reduce!(%Xlsx{} = xlsx, acc, fun), do: Xlsx.reduce(xlsx, acc, fun)
end
