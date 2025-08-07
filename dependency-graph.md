graph TD
    ["<br/>"]
    eu-west-1["eu-west-1<br/>"]
    eu-west-2["eu-west-2<br/>"]
    s3["s3<br/>tfr://terraform-aws-modules/s3-bucket/aws//?version=4.1.2"]
    s3-logs["s3-logs<br/>tfr://terraform-aws-modules/s3-bucket/aws//?version=4.1.2"]
    inspector["inspector<br/>tfr://terraform-aws-modules/inspector/aws//?version=1.0.0"]
    macie["macie<br/>tfr://terraform-aws-modules/macie/aws//?version=1.0.0"]
    elb["elb<br/>tfr://terraform-aws-modules/alb/aws//?version=9.9.2"]
    securitygroup["securitygroup<br/>tfr://terraform-aws-modules/security-group/aws//?version=5.1.2"]
    vpc["vpc<br/>tfr://terraform-aws-modules/vpc/aws//?version=5.8.1"]
    role["role<br/>tfr://terraform-aws-modules/iam/aws//modules/iam-role?version=5.30.0"]
    rds["rds<br/>tfr://terraform-aws-modules/rds/aws//?version=6.6.0"]
    ec2["ec2<br/>tfr://terraform-aws-modules/ec2-instance/aws//?version=5.6.1"]
    waf["waf<br/>tfr://terraform-aws-modules/waf/aws//?version=1.0.0"]
    securitygroup --> rds
    securitygroup --> ec2
    vpc --> rds
    vpc --> ec2