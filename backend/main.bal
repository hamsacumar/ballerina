import ballerina/http;
import ballerinax/mongodb;

// For MongoDB Atlas, use connection string instead
configurable string connectionString = ?;

final mongodb:Client mongoDb = check new ({
    connection: connectionString
});

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
    private final mongodb:Database myDb;

    function init() returns error? {
        self.myDb = check mongoDb->getDatabase("ballerina");
    }

    resource function get data() returns TestDoc[]|error {
        mongodb:Collection collection = check self.myDb->getCollection("test");
        stream<TestDoc, error?> result = check collection->find();
        return from TestDoc doc in result
            select doc;
    }
}

