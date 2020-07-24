# Lambda Deploy Buildkite Plugin

![CI](https://github.com/peakon/lambda-deploy-buildkite-plugin/workflows/CI/badge.svg?branch=master)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for deploying AWS Lambda function code.

## Deploying Lambda Function Code

```yml
steps:
  - name: deploy
    plugins:
      -  peakon/lambda-deploy#v1.1.1:
          function_name: myfunction
          zip_file: deploy-version.zip
          path: path/to/deploy/code
          s3_bucket: deploybucket
          s3_key: deploy/key/name
          region: ap-southeast-2
```

## Configuration

### `function_name` (required)

The name of the AWS Lambda function you wish to update

### `zip_file` (required)

The name of the zip file. If the zip file exists we deploy the file directly to AWS Lambda (via `aws lambda update-function-code --zip-file`).
If the file does not exist we use the `path` to create the zip file. If `s3_bucket` and `s3_key` are declared we will first push the file to S3.

### `path` (optional)

If the `path` is specified with the `zip_file` then the `path` is added to the `zip_file`. If no path is given then we default to the value
of `$PWD` which is added to the `zip_file`. If the path is given but the `zip_file` is not present, then the we `cd` into the `path` and
create a `zip` of the contents which is then uploaded.

### `s3_bucket` (optional)

The S3 bucket. The S3 bucket must already be created and have the correct permissions to copy an object to it.

### `s3_key`

The path to store the S3 key

### `region` (optional)

The region to deploy lambda to. Defaults to `us-east-1`

## License

MIT (see [LICENSE](LICENSE))
