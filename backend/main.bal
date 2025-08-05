import ballerina/http;
import ballerinax/mongodb;

// Import shared database configuration
public type TestDoc record {|
    json _id;
    int testdata;
|};


// Configure CORS - Simple approach for development
@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}


service on new http:Listener(9091) {

    resource function get data() returns TestDoc[]|error {
        mongodb:Collection collection = check myDb->getCollection("test");
        stream<TestDoc, error?> result = check collection->find();
        return from TestDoc doc in result
            select doc;
    }
}

