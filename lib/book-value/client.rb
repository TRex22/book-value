module BookValue
  class Client
    include ::BookValue::Constants

    attr_reader :base_path, :port

    def initialize(port: 443)
      @base_path = BASE_PATH
      @port = port
    end

    def self.api_version
      'v1 2023-03-15'
    end

    # TODO: Handle errors
    def car_makes
      raw_page = authorise_and_send(http_method: :get)
      doc = Nokogiri::HTML(raw_page['body'])

      options = {}
      doc.css("select[name='make'] option").each do |option|
        options[option.text.strip] = { name: option.text.strip, value: option.values.first, img: img_path(option.text.strip) }
      end

      options
    end

    def car_models(make)
      raw_page = authorise_and_send(http_method: :get, command: "calculate/#{make.downcase}")
      doc = Nokogiri::HTML(raw_page['body'])

      options = {}
      doc.css("select[name='model'] option").each do |option|
        options[option.text.strip] = { name: option.text.strip, value: option.values.first }
      end

      options
    end

    # TODO: Fix model to try `-`
    def car_features(make, model)
      checkbox_options = {}

      process_model(model) do |model_name|
        raw_page = authorise_and_send(http_method: :get, command: "calculate/#{make.downcase}/#{model_name}")
        next if raw_page == {}

        doc = Nokogiri::HTML(raw_page['body'])

        doc.css(".list-group li div").each do |checkbox|
          input_of_child = checkbox.children.find { |child| child.name == 'input' }
          label_of_child = checkbox.children.find { |child| child.name == 'label' }

          checkbox_options[input_of_child[:name]] = label_of_child.children.first.to_s
        end
      end

      checkbox_options
    end

    # Features are just the list of features
    # condition_score is between 1-10, 10 is perfect, 1 is bad
    def get_book_value(make, model, features, mileage, year, condition_score = 10)
      output = ''
      feature_params = ''

      process_model(model) do |model_name|
        features.each do |feature_id|
          feature_params = "#{feature_params}#{feature_id}=on&"
        end

        feature_params = feature_params[0..-2]

        milage_form_page = authorise_and_send(http_method: :post, payload: feature_params, command: "calculate/#{make.downcase}/#{model_name}")
        next if milage_form_page == {}

        condition_url = milage_form_page['headers']['location']

        _condition_page = HTTParty.post(condition_url, body: "mileage=#{mileage}&year=#{year}")

        book_value_url = condition_url.gsub('/4', '/5')
        book_value_page = HTTParty.post(book_value_url, body: "condition_score=#{condition_score}")

        doc = Nokogiri::HTML(book_value_page.body)

        output = doc.at('h4').text
      end

      output
    end

    private

    def process_model(model)
      [model.downcase.gsub(' ', ''), model.downcase.gsub(' ', '-')]
    end

    def img_path(name)
      "#{base_path}/data/makes/#{snake_case(name)}"
    end

    def snake_case(str)
      str.downcase.gsub(/\s/, '_')
    end

    def authorise_and_send(http_method:, command: nil, payload: {}, params: {})
      start_time = micro_second_time_now

      if params.nil? || params.empty?
        params = {}
      end

      response = HTTParty.send(
        http_method.to_sym,
        construct_base_path(command, params),
        body: payload,
        headers: {
          'Content-Type': 'application/json',
          "Accept": 'application/json',
        },
        port: port,
        format: :json,
        follow_redirects: false,
      )

      end_time = micro_second_time_now
      construct_response_object(response, command, start_time, end_time)
    end

    def construct_response_object(response, path, start_time, end_time)
      {
        'body' => parse_body(response, path),
        'headers' => response.headers,
        'metadata' => construct_metadata(response, start_time, end_time)
      }
    end

    def construct_metadata(response, start_time, end_time)
      total_time = end_time - start_time

      {
        'start_time' => start_time,
        'end_time' => end_time,
        'total_time' => total_time
      }
    end

    def body_is_present?(response)
      !body_is_missing?(response)
    end

    def body_is_missing?(response)
      response.body.nil? || response.body.empty?
    end

    def parse_body(response, path)
      return [] if response.body == "[]"
      parse_json(response) # Purposely not using HTTParty
    end

    def parse_json(response)
      begin
        JSON.parse(response.body)
      rescue => _e
        response.body
      end
    end

    def micro_second_time_now
      (Time.now.to_f * 1_000_000).to_i
    end

    def construct_base_path(command = nil, params)
      if command
        constructed_path = "#{base_path}/#{command}" # TODO: fix command param
      else
        constructed_path = "#{base_path}/"
      end

      if params != {}
        constructed_path = "#{constructed_path}&#{process_params(params)}"
      end

      constructed_path.gsub('://', ':///').gsub('//', '/')
    end

    def process_params(params)
      params.keys.map { |key| "#{key}=#{params[key]}" }.join('&')
    end

    def process_cursor(cursor, params: {})
      unless cursor.nil? || cursor.empty?
        params['cursor'] = cursor
      end

      params
    end
  end
end
