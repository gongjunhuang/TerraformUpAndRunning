aws-switch ()
{
  export -n AWS_DEFAULT_PROFILE;
  export -n AWS_PROFILE;
  export -n AWS_REGION;
  export -n AWS_ACCESS_KEY_ID;
  export -n AWS_SECRET_ACCESS_KEY;
  export -n AWS_SESSION_TOKEN;
  export -n SAML2AWS_PROFILE;
  export -n AWS_CREDENTIAL_EXPIRATION;
  export -n AWS_SECURITY_TOKEN;
  if [[ "$1" == "china" ]]; then
    PARTITION="--aws-urn=urn:amazon:webservices:cn-north-1";
    REGION="--region cn-north-1";
    export AWS_DEFAULT_REGION=cn-northwest-1;
  else
    PARTITION="";
    REGION="";
    export AWS_DEFAULT_REGION=us-east-1;
  fi;
  saml2aws --skip-prompt login --force $PARTITION $REGION;
  eval $(saml2aws script);
  aws sts get-caller-identity
}
#then do aws-switch china for AWS-CN or just aws-switch for non-China
