program googleapinlpdemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.DateUtils,
  System.IOUtils,
  System.Net.HTTPClient,
  System.Net.HTTPClientComponent,
  System.Net.URLClient,
  System.Classes,
  System.JSON,
  System.Generics.Collections,

  JOSE.Core.JWT,
  JOSE.Core.JWK,
  JOSE.Core.JWS,
  JOSE.Core.JWA,
  JOSE.Types.Bytes;

var
  LToken: TJWT;
  LDT: TDateTime;
  LKey: TJWK;
  LJWS: TJWS;
  LCompactedToken: TJOSEBytes;
  HTTPClient: TNetHTTPClient;
  LStrStream: TStream;
  LResponse: IHTTPResponse;
  LJSONResponse: TJSONObject;
  LHeaders: TNetHeaders;
  LAccessToken: string;
  LJSONReq, LObj, LFeat: TJSONObject;
  LOutputStream: TStringStream;
  LStreamReader: TStreamReader;

begin
  try
    // Create own JWT
    LToken := TJWT.Create;
    LToken.Claims.SetClaimOfType('iss',
      'your_client_email');  //<------------ your client email goes here
    LToken.Claims.SetClaimOfType('scope',
      'https://www.googleapis.com/auth/cloud-language');
    LToken.Claims.Audience := 'https://www.googleapis.com/oauth2/v4/token';
    LToken.Claims.IssuedAt := Now;
    LDT := Now;
    IncMinute(LDT, 30);
    LToken.Claims.Expiration := LDT;
    LKey := TJWK.Create(TFile.ReadAllBytes('key.txt'));
    LJWS := TJWS.Create(LToken);
    LJWS.Sign(LKey, TJOSEAlgorithmId.RS256);
    LCompactedToken := LJWS.CompactToken;

    // Get access token
    HTTPClient := TNetHTTPClient.Create(nil);
    LStrStream := TStringStream.Create
      ('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion='
      + LCompactedToken.AsString);
    SetLength(LHeaders, 1);
    LHeaders[0].Name := 'Content-Type';
    LHeaders[0].Value := 'application/x-www-form-urlencoded';
    LResponse := HTTPClient.Post('https://www.googleapis.com/oauth2/v4/token',
      LStrStream, nil, LHeaders);
    LJSONResponse := TJSONObject.ParseJSONValue(LResponse.ContentAsString)
      as TJSONObject;
    LAccessToken := LJSONResponse.Values['access_token'].Value;
    FreeAndNil(HTTPClient);
    FreeAndNil(LJSONResponse);
    FreeAndNil(LStrStream);

    // Call the API
    HTTPClient := TNetHTTPClient.Create(nil);
    LJSONReq := TJSONObject.Create;
    LJSONReq.AddPair('encodingType', 'UTF8');
    LObj := TJSONObject.Create;
    LObj.AddPair('type', 'PLAIN_TEXT');
    LJSONReq.AddPair('document', LObj);
    LFeat := TJSONObject.Create;
    LFeat.AddPair('extractSyntax', TJSONBool.Create(true));
    LFeat.AddPair('extractDocumentSentiment', TJSONBool.Create(true));
    LJSONReq.AddPair('features', LFeat);
    SetLength(LHeaders, 1);
    LHeaders[0].Value := 'Bearer ' + LAccessToken;
    LHeaders[0].Name := 'Authorization';
    LOutputStream := TStringStream.Create;
    LObj.AddPair('content', 'Hello, my name is Elise!');
    HTTPClient.Post('https://language.googleapis.com/v1/documents:annotateText',
      TStringStream.Create(LJSONReq.ToString), LOutputStream, LHeaders);
    LStreamReader := TStreamReader.Create(LOutputStream);
    Writeln(LStreamReader.ReadToEnd);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;

end.
