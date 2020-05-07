# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# A call such as: "source token.sh"
#
# Dependancies:
#	Shell Commands: All of these must be in the path.
#		aws cli
#		date
#		grep
#		jq
#		stat 
#		uname
#	
# Assumptions:
#   The AWS CLI has already been installed.
#	- "aws configure" has already been succesfully ran and that required keys are in place.
#
#	- The following commands have been issued
#		- "aws configure set account_num <account_number>"
#		- "aws configure set token_email <your.email@example.com>"
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# If you are using a profile name/value other than 'default' then modify the variable below to what you need.
#
PROFILE=default
TOKEN_TTL=129600

if [ -f ~/.aws/.token_info ]; then
    if uname | grep -q "Darwin"; then mod_time_fmt="-f %m"; else mod_time_fmt="-c %Y"; fi
    filemtime=$(stat $mod_time_fmt ~/.aws/.token_info)
    currtime=$(date +%s)
    diff=$(( currtime - filemtime ))
    if (( diff < $TOKEN_TTL )); then
        . ~/.aws/.token_info
    else
        echo "AWS Token has expired, rerun 'token' to activate."
    fi
fi


function token(){
    TOKEN=$@
    re='^[0-9]+$'
    if ! [[ $TOKEN =~ $re ]] ; then
       echo "Token value error: '$TOKEN' is not a number" >&2; return 1
    fi
    acct=$(aws configure get account_num --profile $PROFILE)
    if [ "$acct" = "" ]; then
        echo 'Could not get account number from "aws configure"'
        echo "Token NOT active."
        return 1
    fi
    email=$(aws configure get token_email --profile $PROFILE)
    if [ "$email" = "" ]; then
        echo 'Could not get email address from "aws configure"'
        echo "Token NOT active."
        return 1
    fi
    token_info=$(aws sts get-session-token --serial-number arn:aws:iam::${acct}:mfa/${email} --profile $PROFILE --query Credentials --duration-seconds $TOKEN_TTL --token-code $TOKEN)
    echo "export AWS_ACCESS_KEY_ID=$(echo $token_info | jq -r .AccessKeyId)" > ~/.aws/.token_info
    echo "export AWS_SECRET_ACCESS_KEY=$(echo $token_info | jq -r .SecretAccessKey)" >> ~/.aws/.token_info
    echo "export AWS_SESSION_TOKEN=$(echo $token_info | jq -r .SessionToken)" >> ~/.aws/.token_info
    source ~/.aws/.token_info
}

