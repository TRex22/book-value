require 'httparty'
require 'nokogiri'

require 'book-value/version'
require 'book-value/constants'

# Endpoints
require 'book-value/client'

module BookValue
  class Error < StandardError; end
end
