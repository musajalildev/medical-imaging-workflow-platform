Sentry.init do |config|
  # Sentry is only enabled when the dsn is set.
  unless Rails.env.development? || Rails.env.test?
    config.dsn = 'https://7d3417409d9012da8095c33bb18582c6@sentry.shefcompsci.org.uk/43'
  end
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.before_send = -> (event, hint) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(event.to_hash) }
  config.excluded_exceptions += [
    'ActionController::BadRequest',
    'ActionController::UnknownFormat',
    'ActionController::UnknownHttpMethod',
    'ActionDispatch::Http::MimeNegotiation::InvalidType',
    'CanCan::AccessDenied',
    'Mime::Type::InvalidMimeType',
    'Rack::QueryParser::InvalidParameterError',
    'Rack::QueryParser::ParameterTypeError',
    'SystemExit',
    'URI::InvalidURIError',
  ]
end