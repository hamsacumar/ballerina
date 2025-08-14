import ballerina/http;
import ballerinax/mongodb;
import ballerina/jwt;
import ballerina/crypto;
import ballerina/time;

// Configuration - same as main.bal
configurable string jwtSecret = ?;
configurable string jwtIssuer = ?;

// Types
public type User record {|
    json _id?;
    string username;
    string email;
    string password?;
    string role;
    string createdAt?;
|};

public type RegisterRequest record {|
    string username;
    string email;
    string password;
    string role?;
|};

public type LoginRequest record {|
    string username;
    string password;
|};

public type AuthResponse record {|
    string message;
    string? token?;
    UserResponse? user?;
|};

public type UserResponse record {|
    json _id?;
    string username;
    string email;
    string role;
    string createdAt?;
|};

// JWT Configuration
http:JwtValidatorConfig jwtValidatorConfig = {
    issuer: jwtIssuer,
    audience: "ballerina-users",
    signatureConfig: {
        secret: jwtSecret
    },
    scopeKey: "role"
};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /auth on new http:Listener(9092) {
    private final http:ListenerJwtAuthHandler jwtHandler;

    function init() returns error? {
        self.jwtHandler = new (jwtValidatorConfig);
    }

    private function hashPassword(string password) returns string|error {
        byte[] hashedBytes = crypto:hashSha256(password.toBytes());
        return hashedBytes.toBase16();
    }

    private function verifyPassword(string password, string hashedPassword) returns boolean|error {
        string hashedInput = check self.hashPassword(password);
        return hashedInput == hashedPassword;
    }

    private function createUserResponse(User user) returns UserResponse {
        return {
            _id: user?._id,
            username: user.username,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt ?: ""
        };
    }

    resource function get health() returns json {
        return {"status": "healthy", "service": "auth", "timestamp": time:utcNow()};
    }

    resource function post register(RegisterRequest registerData) returns AuthResponse|http:BadRequest|http:Conflict|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        User? existingUser = check userCollection->findOne({username: registerData.username});
        if existingUser is User {
            return <http:Conflict>{
                body: {"message": "Username already exists"}
            };
        }

        User? existingEmail = check userCollection->findOne({email: registerData.email});
        if existingEmail is User {
            return <http:Conflict>{
                body: {"message": "Email already exists"}
            };
        }

        if registerData.username.length() < 3 {
            return <http:BadRequest>{
                body: {"message": "Username must be at least 3 characters long"}
            };
        }

        if registerData.password.length() < 6 {
            return <http:BadRequest>{
                body: {"message": "Password must be at least 6 characters long"}
            };
        }

        string hashedPassword = check self.hashPassword(registerData.password);
        
        User newUser = {
            username: registerData.username,
            email: registerData.email,
            password: hashedPassword,
            role: registerData.role ?: "user",
            createdAt: time:utcToString(time:utcNow())
        };

        json|mongodb:Error result = userCollection->insertOne(newUser);
        if result is mongodb:Error {
            return error("Failed to create user");
        }
        newUser._id = result;

        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": newUser.role,
                "username": newUser.username,
                "email": newUser.email
            },
            signatureConfig: {
                algorithm: jwt:HS256,
                config: jwtSecret
            }
        };

        jwt:ClientSelfSignedJwtAuthProvider jwtProvider = new (issuerConfig);
        string|jwt:Error token = jwtProvider.generateToken();
        
        if token is jwt:Error {
            return error("Failed to generate token");
        }

        return {
            message: "Registration successful",
            token: token,
            user: self.createUserResponse(newUser)
        };
    }

    resource function post login(LoginRequest loginData) returns AuthResponse|http:BadRequest|http:Unauthorized|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        if loginData.username.length() == 0 || loginData.password.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Username and password are required"}
            };
        }

        User? user = check userCollection->findOne({username: loginData.username});
        
        if user is () {
            return <http:Unauthorized>{
                body: {"message": "Invalid username or password"}
            };
        }

        string userPassword = user.password ?: "";
        boolean isValidPassword = check self.verifyPassword(loginData.password, userPassword);
        if !isValidPassword {
            return <http:Unauthorized>{
                body: {"message": "Invalid username or password"}
            };
        }

        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": user.role,
                "username": user.username,
                "email": user.email
            },
            signatureConfig: {
                algorithm: jwt:HS256,
                config: jwtSecret
            }
        };

        jwt:ClientSelfSignedJwtAuthProvider jwtProvider = new (issuerConfig);
        string|jwt:Error token = jwtProvider.generateToken();
        
        if token is jwt:Error {
            return error("Failed to generate token");
        }

        return {
            message: "Login successful",
            token: token,
            user: self.createUserResponse(user)
        };
    }

    resource function get profile(@http:Header string Authorization) 
            returns UserResponse|http:Unauthorized|http:Forbidden|error {
        
        jwt:Payload|http:Unauthorized authn = self.jwtHandler.authenticate(Authorization);
        if authn is http:Unauthorized {
            return authn;
        }

        http:Forbidden? authz = self.jwtHandler.authorize(<jwt:Payload>authn, ["admin", "user"]);
        if authz is http:Forbidden {
            return authz;
        }

        jwt:Payload payload = <jwt:Payload>authn;
        string? username = <string?>payload["username"];
        
        if username is () {
            return error("Invalid token: missing username");
        }

        mongodb:Collection userCollection = check myDb->getCollection("users");
        User? user = check userCollection->findOne({username: username});
        
        if user is () {
            return error("User not found");
        }

        return self.createUserResponse(user);
    }

    resource function post setup/admin() returns json|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        User? existingAdmin = check userCollection->findOne({username: "admin"});
        if existingAdmin is User {
            return {"message": "Admin user already exists"};
        }

        string hashedPassword = check self.hashPassword("admin123");
        
        User adminUser = {
            username: "admin",
            email: "admin@example.com",
            password: hashedPassword,
            role: "admin",
            createdAt: time:utcToString(time:utcNow())
        };

        json|mongodb:Error insertResult = userCollection->insertOne(adminUser);
        if insertResult is mongodb:Error {
            return error("Failed to create admin user");
        }
        
        return {
            "message": "Admin user created successfully", 
            "username": "admin", 
            "password": "admin123"
        };
    }
}
import ballerina/http;
import ballerinax/mongodb;
import ballerina/jwt;
import ballerina/crypto;
import ballerina/time;

// Configuration - same as main.bal
configurable string jwtSecret = "your-secret-key-here-at-least-32-characters-long";
configurable string jwtIssuer = "ballerina-app";

// Types
public type User record {|
    json _id?;
    string username;
    string email;
    string password?;
    string role;
    string createdAt?;
|};

public type RegisterRequest record {|
    string username;
    string email;
    string password;
    string role?;
|};

public type LoginRequest record {|
    string username;
    string password;
|};

public type AuthResponse record {|
    string message;
    string? token?;
    UserResponse? user?;
|};

public type UserResponse record {|
    json _id?;
    string username;
    string email;
    string role;
    string createdAt?;
|};

// JWT Configuration
http:JwtValidatorConfig jwtValidatorConfig = {
    issuer: jwtIssuer,
    audience: "ballerina-users",
    signatureConfig: {
        secret: jwtSecret
    },
    scopeKey: "role"
};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /auth on new http:Listener(9092) {
    private final http:ListenerJwtAuthHandler jwtHandler;

    function init() returns error? {
        self.jwtHandler = new (jwtValidatorConfig);
    }

    private function hashPassword(string password) returns string|error {
        byte[] hashedBytes = crypto:hashSha256(password.toBytes());
        return hashedBytes.toBase16();
    }

    private function verifyPassword(string password, string hashedPassword) returns boolean|error {
        string hashedInput = check self.hashPassword(password);
        return hashedInput == hashedPassword;
    }

    private function createUserResponse(User user) returns UserResponse {
        return {
            _id: user?._id,
            username: user.username,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt ?: ""
        };
    }

    resource function get health() returns json {
        return {"status": "healthy", "service": "auth", "timestamp": time:utcNow()};
    }

    resource function post register(RegisterRequest registerData) returns AuthResponse|http:BadRequest|http:Conflict|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        User? existingUser = check userCollection->findOne({username: registerData.username});
        if existingUser is User {
            return <http:Conflict>{
                body: {"message": "Username already exists"}
            };
        }

        User? existingEmail = check userCollection->findOne({email: registerData.email});
        if existingEmail is User {
            return <http:Conflict>{
                body: {"message": "Email already exists"}
            };
        }

        if registerData.username.length() < 3 {
            return <http:BadRequest>{
                body: {"message": "Username must be at least 3 characters long"}
            };
        }

        if registerData.password.length() < 6 {
            return <http:BadRequest>{
                body: {"message": "Password must be at least 6 characters long"}
            };
        }

        string hashedPassword = check self.hashPassword(registerData.password);
        
        User newUser = {
            username: registerData.username,
            email: registerData.email,
            password: hashedPassword,
            role: registerData.role ?: "user",
            createdAt: time:utcToString(time:utcNow())
        };

        json|mongodb:Error result = userCollection->insertOne(newUser);
        if result is mongodb:Error {
            return error("Failed to create user");
        }
        newUser._id = result;

        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": newUser.role,
                "username": newUser.username,
                "email": newUser.email
            },
            signatureConfig: {
                algorithm: jwt:HS256,
                config: jwtSecret
            }
        };

        jwt:ClientSelfSignedJwtAuthProvider jwtProvider = new (issuerConfig);
        string|jwt:Error token = jwtProvider.generateToken();
        
        if token is jwt:Error {
            return error("Failed to generate token");
        }

        return {
            message: "Registration successful",
            token: token,
            user: self.createUserResponse(newUser)
        };
    }

    resource function post login(LoginRequest loginData) returns AuthResponse|http:BadRequest|http:Unauthorized|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        if loginData.username.length() == 0 || loginData.password.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Username and password are required"}
            };
        }

        User? user = check userCollection->findOne({username: loginData.username});
        
        if user is () {
            return <http:Unauthorized>{
                body: {"message": "Invalid username or password"}
            };
        }

        string userPassword = user.password ?: "";
        boolean isValidPassword = check self.verifyPassword(loginData.password, userPassword);
        if !isValidPassword {
            return <http:Unauthorized>{
                body: {"message": "Invalid username or password"}
            };
        }

        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": user.role,
                "username": user.username,
                "email": user.email
            },
            signatureConfig: {
                algorithm: jwt:HS256,
                config: jwtSecret
            }
        };

        jwt:ClientSelfSignedJwtAuthProvider jwtProvider = new (issuerConfig);
        string|jwt:Error token = jwtProvider.generateToken();
        
        if token is jwt:Error {
            return error("Failed to generate token");
        }

        return {
            message: "Login successful",
            token: token,
            user: self.createUserResponse(user)
        };
    }

    resource function get profile(@http:Header string Authorization) 
            returns UserResponse|http:Unauthorized|http:Forbidden|error {
        
        jwt:Payload|http:Unauthorized authn = self.jwtHandler.authenticate(Authorization);
        if authn is http:Unauthorized {
            return authn;
        }

        http:Forbidden? authz = self.jwtHandler.authorize(<jwt:Payload>authn, ["admin", "user"]);
        if authz is http:Forbidden {
            return authz;
        }

        jwt:Payload payload = <jwt:Payload>authn;
        string? username = <string?>payload["username"];
        
        if username is () {
            return error("Invalid token: missing username");
        }

        mongodb:Collection userCollection = check myDb->getCollection("users");
        User? user = check userCollection->findOne({username: username});
        
        if user is () {
            return error("User not found");
        }

        return self.createUserResponse(user);
    }

    resource function post setup/admin() returns json|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        User? existingAdmin = check userCollection->findOne({username: "admin"});
        if existingAdmin is User {
            return {"message": "Admin user already exists"};
        }

        string hashedPassword = check self.hashPassword("admin123");
        
        User adminUser = {
            username: "admin",
            email: "admin@example.com",
            password: hashedPassword,
            role: "admin",
            createdAt: time:utcToString(time:utcNow())
        };

        json|mongodb:Error insertResult = userCollection->insertOne(adminUser);
        if insertResult is mongodb:Error {
            return error("Failed to create admin user");
        }
        
        return {
            "message": "Admin user created successfully", 
            "username": "admin", 
            "password": "admin123"
        };
    }
}