# frozen_string_literal: true

# CSV Decision: CSV based Ruby decision tables.
# Created December 2017 by Brett Vickers
# See LICENSE and README.md for details.
module CSVDecision
  class Error < StandardError; end
  class CellValidationError < Error; end
  class FileError < Error; end

  # Builds a decision table from the input data - which may either be a file, CSV string
  # or an array of arrays.
  #
  # @param data [Pathname, File, Array<Array<String>>, String] - input data given as
  #   a file, array of arrays or CSV string.
  # @param options [Hash] - options hash supplied by the user
  #   * first_match:     Stop after finding the first match.
  #   * regexp_implicit: Set to make regular expressions implicit rather than requiring
  #                      the comparator =~. (Insidious, use with care.)
  #   * text_only:       Set to make all cells be treated as simple strings by turning
  #                      off all special matchers.
  #   * matchers         May be used to control the inclusion and ordering of special
  #                      matchers. (Advanced feature, use with care.)
  # @return [CSVDecision::Table] - resulting decision table
  def self.parse(data, options = {})
    Parse.table(input: data, options: Options.normalize(options))
  end

  # Parse the CSV file and create a new decision table object.
  #
  # (see #parse)
  module Parse
    def self.table(input:, options:)
      table = CSVDecision::Table.new

      # In most cases the decision table will be loaded from a CSV file.
      table.file = input if Data.input_file?(input)

      parse_table(table: table, input: input, options: options)

      table.freeze
    rescue CSVDecision::Error => exp
      raise_error(file: table.file, exception: exp)
    end

    def self.raise_error(file:, exception:)
      raise exception unless file

      raise CSVDecision::FileError,
            "error processing CSV file #{file}\n#{exception.inspect}"
    end
    private_class_method :raise_error

    def self.parse_table(table:, input:, options:)
      # Parse input data into an array of arrays
      table.rows = Data.to_array(data: input)

      # Pick up any options specified in the CSV file before the header row.
      # These override any options passed as parameters to the parse method.
      table.options = Options.from_csv(rows: table.rows, options: options).freeze

      # Parse the header row
      table.columns = CSVDecision::Columns.new(table)

      parse_data(table: table, matchers: Matchers.new(options))
    end
    private_class_method :parse_table

    def self.parse_data(table:, matchers:)
      table.rows.each_with_index do |row, index|
        table.scan_rows[index] = matchers.parse_ins(columns: table.columns.ins, row: row)
        table.outs_rows[index] = matchers.parse_outs(columns: table.columns.outs, row: row)

        row.freeze
      end

      table.columns.freeze
    end
    private_class_method :parse_data
  end
end