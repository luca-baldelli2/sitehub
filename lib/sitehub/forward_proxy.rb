# rubocop:disable Metrics/ParameterLists
require 'sitehub/http_headers'
require 'sitehub/request_mapping'
require 'sitehub/rules'
require 'sitehub/resolver'
require 'faraday'
require 'sitehub/constants'
class SiteHub
  class ForwardProxy
    ERROR_RESPONSE = Rack::Response.new(['error'], 500, {})

    include HttpHeaders, Rules, Resolver, Constants

    attr_reader :url, :id, :mapped_path, :http_client, :sitehub_cookie_path, :sitehub_cookie_name

    def initialize(url:, id:, mapped_path: nil, rule: nil, sitehub_cookie_path: nil, sitehub_cookie_name:)
      @id = id
      @url = url
      @rule = rule
      @mapped_path = mapped_path
      @sitehub_cookie_path = sitehub_cookie_path
      @sitehub_cookie_name = sitehub_cookie_name
      @http_client = Faraday.new(ssl: { verify: false }) do |con|
        con.adapter :em_synchrony
      end
    end

    def call(env)
      source_request = Rack::Request.new(env)
      request_mapping = env[REQUEST_MAPPING] = request_mapping(source_request)
      mapped_uri = URI(request_mapping.computed_uri)

      downstream_response = proxy_call(request_headers(mapped_uri, source_request), mapped_uri, source_request)

      response(downstream_response, source_request)
    rescue StandardError => e
      env[ERRORS] << e.message
      ERROR_RESPONSE.dup
    end

    def response(response, source_request)
      Rack::Response.new(response.body, response.status, sanitise_headers(response.headers)).tap do |r|
        r.set_cookie(sitehub_cookie_name, path: (sitehub_cookie_path || source_request.path), value: id)
      end
    end

    def request_headers(mapped_uri, source_request)
      headers = sanitise_headers(extract_http_headers(source_request.env))
      headers[HOST_HEADER] = "#{mapped_uri.host}:#{mapped_uri.port}"
      headers[X_FORWARDED_HOST_HEADER] = append_host(headers[X_FORWARDED_HOST_HEADER].to_s, source_request.url)
      headers
    end

    def proxy_call(headers, mapped_uri, source_request)
      http_client.send(source_request.request_method.downcase, mapped_uri) do |request|
        request.headers = headers
        request.body = source_request.body.read
        request.params = source_request.params
      end
    end

    def request_mapping(source_request)
      RequestMapping.new(source_url: source_request.url, mapped_url: url, mapped_path: mapped_path)
    end

    def ==(other)
      other.is_a?(ForwardProxy) && url == other.url
    end

    private

    def append_host(forwarded_host, destination_uri)
      destination_uri = URI(destination_uri)
      if forwarded_host == EMPTY_STRING
        "#{destination_uri.host}:#{destination_uri.port}"
      else
        "#{forwarded_host},#{destination_uri.host}"
      end
    end
  end
end
