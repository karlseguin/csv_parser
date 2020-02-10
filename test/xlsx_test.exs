defmodule CsvParser.Tests.Xlsx do
	use CsvParser.Tests.Base

	@common "test/data/common.xlsx"

	test "error on unknown file" do
		assert CsvParser.read("invalid", type: :xlsx) == {:error, :enoent}
	end

	test "error on unknown sheet" do
		assert CsvParser.read(@common, sheet_index: 9000) == {:error, :unknown_sheet}
	end

	test "error on unknown sheet!" do
		assert_raise RuntimeError, "unknown_sheet", fn -> CsvParser.read!(@common, sheet_index: 4928) end
	end

	test "reads a file with defautl options" do
		expected = [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", "32", "15/10/2017"]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", "Philip", "37", "21/05/2015"]},
			{:ok, ["3549", "Kathleen", "25", "15/10/2017"]},
		]

		assert CsvParser.read!(@common, sheet_index: 1) == expected
		assert CsvParser.read(@common, sheet_index: 1) == {:ok, expected}
		assert CsvParser.read!(@common, sheet_index: 1, type: :xlsx) == expected
	end

	test "reads the specified sheet" do
		assert CsvParser.read!(@common, sheet_index: 2) == [{:ok, ["test"]}]
	end

	test "different column count" do
		assert CsvParser.read!(@common, sheet_index: 3) == [
			{:ok, ["a", "b"]},
			{:ok, ["c"]},
			{:ok, ["1", "2", "3"]}
		]
	end
end
