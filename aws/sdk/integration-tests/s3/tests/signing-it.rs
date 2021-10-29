/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0.
 */

use aws_http::user_agent::AwsUserAgent;
use aws_sdk_s3::operation::ListObjectsV2;
use aws_sdk_s3::{Credentials, Region};
use aws_smithy_client::test_connection::TestConnection;
use aws_smithy_http::body::SdkBody;
use std::time::{Duration, UNIX_EPOCH};

#[tokio::test]
async fn test_signer() -> Result<(), aws_sdk_s3::Error> {
    let creds = Credentials::from_keys(
        "ANOTREAL",
        "notrealrnrELgWzOk3IfjzDKtFBhDby",
        Some("notarealsessiontoken".to_string()),
    );
    let conf = aws_sdk_s3::Config::builder()
        .credentials_provider(creds)
        .region(Region::new("us-east-1"))
        .build();
    let conn = TestConnection::new(vec![(
        http::Request::builder()
            .header("authorization", "AWS4-HMAC-SHA256 Credential=ANOTREAL/20210618/us-east-1/s3/aws4_request, SignedHeaders=content-length;content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token;x-amz-user-agent, Signature=c55fb770a89c535e56b502f8c949766c7bde7cfc84f89d2b7761d13b8e82234c")
            .uri("https://s3.us-east-1.amazonaws.com/test-bucket?list-type=2&prefix=prefix~")
            .body(SdkBody::empty())
            .unwrap(),
        http::Response::builder().status(200).body("").unwrap(),
    )]);
    let client = aws_hyper::Client::new(conn.clone());
    let mut op = ListObjectsV2::builder()
        .bucket("test-bucket")
        .prefix("prefix~")
        .build()
        .unwrap()
        .make_operation(&conf)
        .await
        .unwrap();
    op.properties_mut()
        .insert(UNIX_EPOCH + Duration::from_secs(1624036048));
    op.properties_mut().insert(AwsUserAgent::for_tests());

    client.call(op).await.expect_err("empty response");
    conn.assert_requests_match(&[]);
    Ok(())
}
