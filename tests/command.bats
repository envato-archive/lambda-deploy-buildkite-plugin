#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# Uncomment to enable stub debug output:
#export AWS_STUB_DEBUG=/dev/tty
#export ZIP_STUB_DEBUG=/dev/tty
#export OPENSSL_STUB_DEBUG=/dev/tty
#export BASE64_STUB_DEBUG=/dev/tty
#export JQ_STUB_DEBUG=/dev/tty

setup()
{
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_FUNCTION_NAME="myfunc"
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_PATH="fake/path"
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_ZIP_FILE="myfunc-2323.zip"
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_REGION="ap-southeast-2"
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_BUCKET="myfuncbucket"
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_KEY="deploy_code/production/myfunc-2323.zip"
  mkdir -p fake/path
}

teardown() {
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_FUNCTION_NAME
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_PATH
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_ZIP_FILE
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_REGION
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_BUCKET
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_KEY
  rm -rf fake
  rm -f myfunc-2323.zip
}

@test "Command runs without errors" {
  stub zip \
    "-r /plugin/fake/path/myfunc-2323.zip * : echo 'ok %d %s%s\n'"
  stub openssl \
    "dgst -sha256 -binary /plugin/fake/path/myfunc-2323.zip : echo 'binarydata'"
  stub base64 \
    ": echo 'TWpJeU1qSXlNakl5TWpJSwo='"
  stub aws \
    "s3 cp --acl private --region ap-southeast-2 /plugin/fake/path/myfunc-2323.zip s3://myfuncbucket/deploy_code/production/myfunc-2323.zip : echo 'upload: test.txt to s3://myfuncbucket/deploy_code/production/myfunc-2323.zip'" \
    "lambda update-function-code --publish --function-name myfunc --region ap-southeast-2 --s3-bucket myfuncbucket --s3-key deploy_code/production/myfunc-2323.zip : cat tests/lambda_output.json"
  stub jq \
    "'.CodeSha256' : echo 'TWpJeU1qSXlNakl5TWpJSwo='"

  run "$PWD/hooks/command"
  assert_success
  assert_output --partial "upload: test.txt to s3://myfuncbucket/deploy_code/production/myfunc-2323.zip"
  assert_output --partial "Successfully uploaded new function code with SHA TWpJeU1qSXlNakl5TWpJSwo="

  unstub zip
  unstub aws
  unstub openssl 
  unstub base64
  unstub jq
}

@test "Command runs without error if just zip file given" {
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_BUCKET
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_KEY

  stub openssl \
    "dgst -sha256 -binary /plugin/fake/path/myfunc-2323.zip : echo 'binarydata'"
  stub base64 \
    ": echo 'TWpJeU1qSXlNakl5TWpJSwo='"  
  stub aws \
    "lambda update-function-code --publish --function-name myfunc --region ap-southeast-2 --zip-file fileb:///plugin/fake/path/myfunc-2323.zip : cat tests/lambda_output.json"
  stub jq \
    "'.CodeSha256' : echo 'TWpJeU1qSXlNakl5TWpJSwo='"

  touch fake/path/myfunc-2323.zip
  run "$PWD/hooks/command"
  assert_success
  assert_output --partial "Successfully uploaded new function code with SHA TWpJeU1qSXlNakl5TWpJSwo="

  unstub aws
  unstub openssl
  unstub base64
  unstub jq
}

@test "Command runs without error if just zip file given and no path" {
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_BUCKET
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_KEY
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_PATH

  stub openssl \
    "dgst -sha256 -binary /plugin/myfunc-2323.zip : echo 'binarydata'"
  stub base64 \
    ": echo 'TWpJeU1qSXlNakl5TWpJSwo='"  
  stub aws \
    "lambda update-function-code --publish --function-name myfunc --region ap-southeast-2 --zip-file fileb:///plugin/myfunc-2323.zip : cat tests/lambda_output.json"
  stub jq \
    "'.CodeSha256' : echo 'TWpJeU1qSXlNakl5TWpJSwo='"

  touch myfunc-2323.zip
  run "$PWD/hooks/command"
  assert_success
  assert_output --partial "S3 bucket or key not provided, copying up zip file direct to lambda"
  assert_output --partial "Successfully uploaded new function code with SHA TWpJeU1qSXlNakl5TWpJSwo="

  unstub aws
  unstub openssl
  unstub base64
  unstub jq
}

@test "Command runs with error when checksum returned from AWS is not the same" {
  stub zip \
    "-r /plugin/fake/path/myfunc-2323.zip * : echo 'ok %d %s%s\n'"
  stub openssl \
    "dgst -sha256 -binary /plugin/fake/path/myfunc-2323.zip : echo 'binarydata'"
  stub base64 \
    ": echo 'TWpJeU1qSXlNakl5TWpJSwo='"
  stub aws \
    "s3 cp --acl private --region ap-southeast-2 /plugin/fake/path/myfunc-2323.zip s3://myfuncbucket/deploy_code/production/myfunc-2323.zip : echo 'upload: test.txt to s3://myfuncbucket/deploy_code/production/myfunc-2323.zip'" \
    "lambda update-function-code --publish --function-name myfunc --region ap-southeast-2 --s3-bucket myfuncbucket --s3-key deploy_code/production/myfunc-2323.zip : cat tests/lambda_output.json"
  stub jq \
    "'.CodeSha256' : echo 'NOTAGOODSHA'"

  run "$PWD/hooks/command"
  assert_failure
  assert_output --partial "upload: test.txt to s3://myfuncbucket/deploy_code/production/myfunc-2323.zip"
  assert_output --partial "zip file (TWpJeU1qSXlNakl5TWpJSwo=) does not match the returned checksum from AWS (NOTAGOODSHA)"

  unstub zip
  unstub aws
  unstub openssl 
  unstub base64
  unstub jq
}

@test "Command runs with error when zip file path not found" {
  export BUILDKITE_PLUGIN_LAMBDA_DEPLOY_PATH="fake/path/not/found"

  run "$PWD/hooks/command"
  assert_failure
  assert_output --partial "🚨: Path for zip file not found"
}

@test "Command errors if no zip or s3 details given" {
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_BUCKET
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_S3_KEY
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_ZIP_FILE

  run "$PWD/hooks/command"
  assert_failure
  assert_output --partial "🚨: You must supply a zip file name"
}

@test "Command errors if no function name given" {
  unset BUILDKITE_PLUGIN_LAMBDA_DEPLOY_FUNCTION_NAME

  run "$PWD/hooks/command"
  assert_failure
  assert_output --partial "🚨: You must supply a function name"
}
