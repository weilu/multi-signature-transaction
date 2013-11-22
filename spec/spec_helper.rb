require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.around(:each, :cassette) do |example|
    cassette_name = example.metadata.full_description.split(' ').join('_')
    VCR.use_cassette(cassette_name) do
      example.run
    end
  end
end
