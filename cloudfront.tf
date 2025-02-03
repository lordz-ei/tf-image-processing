module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 4.0"

  comment = "Image Optimization CloudFront with Failover"

  create_origin_access_control = true
  origin_access_control = {
    s3_oac = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }
  
  origin = {
    transformed_s3 = {
      domain_name = module.transformed_s3_bucket.s3_bucket_bucket_domain_name
      origin_access_control = "s3_oac"
    }

    lambda_failover = {
      domain_name = "${module.image_optimization_lambda.lambda_function_url_id}.lambda-url.${data.aws_region.current.name}.on.aws"
      origin_id   = "LambdaFailover"
    }
  }

   origin_group = {
    group_one = {
      failover_status_codes      = [403, 404, 500, 502]
      primary_member_origin_id   = "transformed_s3"
      secondary_member_origin_id = "lambda_failover"
    }
  }
  
  default_cache_behavior = {
    target_origin_id       = "TransformedS3Bucket"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values = {
      query_string = true
      headers      = ["Accept"]
    }

    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl

    function_association = {
        # Valid keys: viewer-request, viewer-response
        viewer-request = {
          function_arn = aws_cloudfront_function.cloudfront_url_rewrite.arn
        }
    }

  logging_config = {
    include_cookies = false
    bucket          = module.cloudfront_logs.s3_bucket_bucket_domain_name
    prefix          = "cloudfront-logs/"
  }


    geo_restriction = {
      restriction_type = "none"
    }
  

  viewer_certificate = {
    cloudfront_default_certificate = true
  }
}
}