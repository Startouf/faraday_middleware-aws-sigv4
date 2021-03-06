RSpec.describe FaradayMiddleware::AwsSigV4 do
  def faraday(options = {})
    options = {
      url: 'https://apigateway.us-east-1.amazonaws.com'
    }.merge(options)

    Faraday.new(options) do |faraday|
      aws_sigv4_options = {
        service: 'apigateway',
        region: 'us-east-1',
        access_key_id: 'akid',
        secret_access_key: 'secret',
      }

      faraday.request :aws_sigv4, aws_sigv4_options
      faraday.response :json, :content_type => /\bjson\b/

      faraday.adapter(:test, Faraday::Adapter::Test::Stubs.new) do |stub|
        yield(stub)
      end
    end
  end

  let(:response) do
    {'accountUpdate'=>
      {'name'=>nil,
       'template'=>false,
       'templateSkipList'=>nil,
       'title'=>nil,
       'updateAccountInput'=>nil},
     'cloudwatchRoleArn'=>nil,
     'self'=>
      {'__type'=>
        'GetAccountRequest:http://internal.amazon.com/coral/com.amazonaws.backplane.controlplane/',
       'name'=>nil,
       'template'=>false,
       'templateSkipList'=>nil,
       'title'=>nil},
     'throttleSettings'=>{'burstLimit'=>1000, 'rateLimit'=>500.0}}
  end

  let(:signed_headers) do
    'host;user-agent;x-amz-content-sha256;x-amz-date'
  end

  let(:default_expected_headers) do
    {'User-Agent'=>"Faraday v#{Faraday::VERSION}",
     'host'=>'apigateway.us-east-1.amazonaws.com',
     'x-amz-date'=>'20150101T000000Z',
     'x-amz-content-sha256'=>
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'authorization'=>
      'AWS4-HMAC-SHA256 Credential=akid/20150101/us-east-1/apigateway/aws4_request, ' +
      "SignedHeaders=#{signed_headers}, " +
      "Signature=#{signature}"}
  end

  let(:additional_expected_headers) { {} }

  let(:expected_headers) do
    default_expected_headers.merge(additional_expected_headers)
  end

  let(:client) do
    faraday do |stub|
      stub.get('/account') do |env|
        expected_headers_without_authorization = expected_headers.dup
        authorization = expected_headers_without_authorization.delete('authorization')
        expect(env.request_headers).to include expected_headers_without_authorization
        expect(env.request_headers.fetch('authorization')).to match Regexp.new(authorization)
        [200, {'Content-Type' => 'application/json'}, JSON.dump(response)]
      end
    end
  end

  context 'without query' do
    let(:signature) do
      '(' + %w(
        4029fcbe5aae50c588651d5a587f4a9fd2b7ba25bc03e1ce57432c758d1a7816
        024535e1dd5a9f9eb5a8d2eb99c64678766ad6059bdd51ad85d282f49bd20700
      ).join('|') + ')'
    end

    subject { client.get('/account').body }
    it { is_expected.to eq response }
  end

  context 'with query' do
    subject { client.get('/account', params).body }

    context 'include space' do
      let(:signature) do
        '(' + %w(
          75bb1b4dbbf7b7a502ecb574abfcc2e12ce115da07f876d3b66fd3ff0ad427fd
          f0a9030e2e15012d61af8b708ad358c9a5e5495984162884abf1cb910275223b
        ).join('|') + ')'
      end

      let(:params) { {foo: 'b a r', zoo: 'b a z'} }
      it { is_expected.to eq response }
    end

    context 'not include space' do
      let(:signature) do
        '(' + %w(
          94e01cc599b3eef64cc9e08c5f079b0345d5b9dd95cc14d0ea66fc0c5923bf30
          8c58f5f0decfb7f185d290bae83dac382328ba19c862861fd646089ba0083569
        ).join('|') + ')'
      end

      let(:params) { {foo: 'bar', zoo: 'baz'} }
      it { is_expected.to eq response }
    end
  end
end
