defmodule CsvParser.Tests.Csv do
	use CsvParser.Tests.Base

	@common "test/data/common.csv"
	@jagged_rows "test/data/jagged_rows.csv"

	test "reads a file with defautl options" do
		expected = [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", "32", "15/10/2017"]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", "Philip", "37", "21/05/2015"]},
			{:ok, ["3549", "Kathleen", "25", "15/10/2017"]},
		]

		assert CsvParser.read!(@common) == expected
		assert CsvParser.read(@common) == {:ok, expected}
		assert CsvParser.read!(@common, type: :csv) == expected
	end

	test "error on unknown file" do
		assert CsvParser.read("404", type: :csv) == {:error, :enoent}
		assert_raise RuntimeError, "enoent", fn -> CsvParser.read!("404", type: :csv) end
	end

	test "different column count" do
		assert CsvParser.read!(@jagged_rows) == [
			{:ok, ["a", "b"]},
			{:ok, ["c"]},
			{:ok, ["1", "2", "3"]}
		]

		assert CsvParser.read!(@jagged_rows, validate_row_length: true) == [
			{:ok, ["a", "b"]},
			{:error, "Row has length 1 - expected length 2 on line 2"},
			{:error, "Row has length 3 - expected length 2 on line 3"}
		]
	end

end
