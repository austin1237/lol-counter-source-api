const  uuid  = require('uuid');

exports.handler = async function (event, context) {
  const response = {
    "statusCode": 200,
    "headers": {},
    "body": JSON.stringify(`lambda hit ${uuid.v4()}`),
    "isBase64Encoded": false
};
  return response
};
