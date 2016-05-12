var querystring,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

querystring = require('querystring');

module.exports = function(env) {
  var OAuth2ResponseParser, OAuthResponseParser, check, errors_desc;
  check = env.utilities.check;
  OAuthResponseParser = require('./oauth-response-parser')(env);
  errors_desc = {
    authorize: {
      'invalid_request': "The request is missing a required parameter, includes an unsupported parameter or parameter value, or is otherwise malformed.",
      'invalid_client': "The client identifier provided is invalid.",
      'unauthorized_client': "The client is not authorized to use the requested response type.",
      'redirect_uri_mismatch': "The redirection URI provided does not match a pre-registered value.",
      'access_denied': "The end-user or authorization server denied the request.",
      'unsupported_response_type': "The requested response type is not supported by the authorization server.",
      'invalid_scope': "The requested scope is invalid, unknown, or malformed."
    },
    access_token: {
      'invalid_request': "The request is missing a required parameter, includes an unsupported parameter or parameter value, repeats a parameter, includes multiple credentials, utilizes more than one mechanism for authenticating the client, or is otherwise malformed.",
      'invalid_client': "The client identifier provided is invalid, the client failed to authenticate, the client did not include its credentials, provided multiple client credentials, or used unsupported credentials type.",
      'unauthorized_client': "The authenticated client is not authorized to use the access grant type provided.",
      'invalid_scope': "The requested scope is invalid, unknown, malformed, or exceeds the previously granted scope.",
      'invalid_grant': "The provided access grant is invalid, expired, or revoked (e.g. invalid assertion, expired authorization token, bad end-user password credentials, or mismatching authorization code and redirection URI).",
      'unsupported_grant_type': "The access grant included - its type or another attribute - is not supported by the authorization server."
    }
  };
  OAuth2ResponseParser = (function(superClass) {
    extend(OAuth2ResponseParser, superClass);

    function OAuth2ResponseParser(response, body, format, tokenType) {
      OAuth2ResponseParser.__super__.constructor.call(this, response, body, format, tokenType);
    }

    OAuth2ResponseParser.prototype.parse = function(callback) {
      return OAuth2ResponseParser.__super__.parse.call(this, (function(_this) {
        return function(e, r) {
          var ref, ref1;
          if (((ref = _this.body) != null ? ref.error : void 0) || ((ref1 = _this.body) != null ? ref1.error_description : void 0)) {
            return callback(_this._setError(_this.body.error_description || errors_desc[_this.body.error] || 'Error in response'));
          }
          if (e) {
            return callback(e);
          }
          if (!_this.body.access_token) {
            return callback(_this._setError('access_token not found'));
          }
          _this.access_token = _this.body.access_token;
          return callback(null, _this);
        };
      })(this));
    };

    return OAuth2ResponseParser;

  })(OAuthResponseParser);
  OAuth2ResponseParser.errors_desc = errors_desc;
  return OAuth2ResponseParser;
};
