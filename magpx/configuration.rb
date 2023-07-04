require 'yaml'
require 'digest'

require 'active_support/all'
require 'net/http'


module MagGPX
  module Configuration
    DEBUG = false

    mattr_accessor :config

    module_function
    LOGIN_ENDPOINT = "http://rfs-fitness.rfsvr.com/api/v1/app/login"

    CONFIG_FILE = '~/.magpx.yml'

    DEFAULT_OPTIONS = {
      username: nil,
      password: nil,
      token: nil,
      mapbox_token: nil,
      import_prefix: nil,
      import_gpx: nil,
      login: false,
    }.freeze

    def configure
      options = DEFAULT_OPTIONS.dup.with_indifferent_access
      real_config_file = File.expand_path(CONFIG_FILE)

      options.merge!(YAML.load(File.read(real_config_file))) if File.exist?(real_config_file)

      OptionParser.new do |opts|
        opts.on('-u', '--username', '=USERNAME', 'Specify the OneLapFit username (required if token not present)') do |username|
          options[:username] = username
        end
        opts.on('-p', '--password', '=PASSWORD', 'Specify the OneLapFit password (required if token not present)') do |password|
          options[:password] = password
        end
        opts.on('-t', '--token', '=PASSWORD', 'Specify the OneLapFit access token (required if username/password not present)') do |token|
          options[:token] = token
        end
        opts.on('-m', '--mapbox-token', '=MAPBOX_TOKEN',
                'Specify the mapbox token (for routing functions)') do |mapbox_token|
          options[:mapbox_token] = mapbox_token
        end
        opts.on('-g', '--import-gpx', '=FILENAME', 'GPX file to import') do |import_gpx|
          options[:import_gpx] = import_gpx
        end
        if Configuration.debug?
          opts.on('-i', '--import-prefix', '=PREFIX', 'Import all files matching prefix-????.json') do |import_prefix|
            options[:import_prefix] = import_prefix
          end
        end
        opts.on('-l', '--login', 'Login and persist token to ~/.magpx') do |login|
          options[:login] = login
        end
      end.parse!

      raise StandardError, 'Please enter username or password' if (options[:username].nil? || options[:password].nil?) && options[:token].nil?

      Configuration.config = options.with_indifferent_access
    end

    def login(username, password)
      real_config_file = File.expand_path(CONFIG_FILE)
      configuration = File.exist?(real_config_file) ? YAML.load(File.read(real_config_file)) : {}
      configuration[:session_id] = SecureRandom.uuid
      configuration[:device_id] = SecureRandom.uuid
      headers = request_headers({
                                  DeviceId: configuration[:device_id],
                                  SessionId: configuration[:session_id]
                                }, authenticated: false)
      response = Net::HTTP.post(URI(LOGIN_ENDPOINT),
                                { account: username, password: Digest::MD5.hexdigest(password) }.to_json,
                                headers)

      resp = JSON.parse(response.body).with_indifferent_access
      raise StandardError, "Error during login/password\n#{response.body}" if resp[:code] != 200
      configuration[:token] = resp[:data][:token]
      configuration[:user_id] = resp[:data][:userinfo][:uid]
      configuration[:mapbox_token] = Configuration.config[:mapbox_token].presence || "insert"

      File.open(real_config_file, 'w') do |file|
        file.write(configuration.stringify_keys.to_yaml)
        puts "Configuration saved to #{real_config_file}"
      end
      Configuration.config = configuration.with_indifferent_access
    end

    def request_headers(extra = {}, authenticated: true)
      headers = {
        Language: "en",
        "User-Agent": "wanlu/1.5.3 (iPad; iOS 16.4; Scale/2.00)",
        Version: "1.5.3",
        Platform: "43",
        "Accept-Language": "en;q=1",
        DeviceId: Configuration.config[:device_id],
        SessionId: Configuration.config[:session_id],
        Timezone: "America/Toronto",
        "Content-Type": "application/json",
        "App-Version": "1.5.3",
        "App-Name": "onelapfit",
      }

      headers.merge!(Authorization: Configuration.config[:token], UserId: Configuration.config[:user_id].to_s) if authenticated
      headers.merge(extra)
    end

    def authenticated?
      Configuration.config[:token].present? && Configuration.config[:user_id].present?
    end

    def debug?
      DEBUG.present?
    end
  end
end
