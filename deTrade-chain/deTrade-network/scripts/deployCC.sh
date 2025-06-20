#!/bin/bash

source scripts/utils.sh

# 组织数量

CHANNEL_NAME=${1:-"mychannel"}
CC_NAME=${2}
CC_SRC_PATH=${3}
CC_SRC_LANGUAGE=${4}
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}
Nums_Org=${13:-"20"}
Nums_Peer=${14:-"25"}
# CHANNEL_NAME="mychannel"
# CRYPTO_MODE="Certificate Authorities"
# CC_NAME="datatrading"
# CC_SRC_PATH="../datatrading-chaincode/chaincode-go/"
# CC_SRC_LANGUAGE="go"

println "executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"

INIT_REQUIRED="--init-required"
# check if the init fcn should be called
if [ "$CC_INIT_FCN" = "NA" ]; then
  INIT_REQUIRED=""
fi

if [ "$CC_END_POLICY" = "NA" ]; then
  CC_END_POLICY=""
else
  CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
  CC_COLL_CONFIG=""
else
  CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi

FABRIC_CFG_PATH=$PWD/../config/

# import utils
. scripts/envVar.sh
. scripts/ccutils.sh

function checkPrereqs() {
  jq --version > /dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    errorln "jq command not found..."
    errorln
    errorln "Follow the instructions in the Fabric docs to install the prereqs"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/prereqs.html"
    exit 1
  fi
}

#check for prerequisites
checkPrereqs

## package the chaincode
./scripts/packageCC.sh $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION 

PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)


# 安装链码到该组织的所有节点
for (( i=1; i<=$Nums_Org; i++ ))
do
  for (( p=0; p<$Nums_Peer; p++ ))
  do
    infoln "Installing chaincode on peer${p}.org${i}..."
    installChaincode $i $p
  done
done


resolveSequence

# 查询每个组织的每个节点是否安装链码
for (( i=1; i<=$Nums_Org; i++ ))
do
  for ((  p=0; p<$Nums_Peer; p++ ))
  do
    queryInstalled $i $p
  done
done



# 每个组织批准一次
for (( i=1; i<=$Nums_Org; i++ ))
do
  approveForMyOrg $i
done


# checkCommitReadiness用于验证各个节点是否批准，一个组织使用一个节点(这里忽略)

# 使用代表节点提交链码定义
infoln "Committing chaincode definition using representative peers..."
commitChaincodeDefinition $(seq -s " " 1 $Nums_Org)
# commitChaincodeDefinition 1 2 3 4 5 6 7 8 9 10


# 查询组织是否有链码定义
for (( i=1; i<=$Nums_Org; i++ ))
do
  queryCommitted $i 
done


# ## Install chaincode on peer0.org1 and peer0.org2
# infoln "Installing chaincode on peer0.org1..."
# installChaincode 1
# infoln "Install chaincode on peer0.org2..."
# installChaincode 2
# infoln "Install chaincode on peer0.org3..."
# installChaincode 3

# resolveSequence

# ## query whether the chaincode is installed
# queryInstalled 1

# ## approve the definition for org1
# approveForMyOrg 1

# ## check whether the chaincode definition is ready to be committed
# ## expect org1 to have approved and org2 not to
# checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
# checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"
# checkCommitReadiness 3 "\"Org1MSP\": true" "\"Org2MSP\": false" "\"Org3MSP\": false"


# ## now approve also for org2
# approveForMyOrg 2

# ## check whether the chaincode definition is ready to be committed
# ## expect them both to have approved
# checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
# checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"
# checkCommitReadiness 3 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": false"

# approveForMyOrg 3

# checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
# checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"
# checkCommitReadiness 3 "\"Org1MSP\": true" "\"Org2MSP\": true" "\"Org3MSP\": true"

# ## now that we know for sure both orgs have approved, commit the definition
# commitChaincodeDefinition 1 2 3

# ## query on both orgs to see that the definition committed successfully
# queryCommitted 1
# queryCommitted 2
# queryCommitted 3

# ## Invoke the chaincode - this does require that the chaincode have the 'initLedger'

# ## method defined
# if [ "$CC_INIT_FCN" = "NA" ]; then
#   infoln "Chaincode initialization is not required"
# else
#   chaincodeInvokeInit 1 2 3
# fi

# exit 0

