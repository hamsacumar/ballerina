import ballerina/http;
import ballerinax/mongodb;
import ballerina/jwt;
import ballerina/crypto;
import ballerina/time;
import ballerina/email;
import ballerina/random;
import ballerina/log;

// Configuration - add email configuration
configurable string jwtSecret = ?;
configurable string jwtIssuer = ?;
configurable string smtpHost = ?;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable int smtpPort = 587;

// Types
public type User record {|
    json _id?;
    string username;
    string email;
    string password?;
    string role;
    string createdAt?;
    boolean isEmailVerified?;
    string? verificationCode?;
    string? verificationExpiry?;
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

public type VerifyEmailRequest record {|
    string email;
    string verificationCode;
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
    boolean isEmailVerified?;
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
    private final email:SmtpClient smtpClient;

    function init() returns error? {
        self.jwtHandler = new (jwtValidatorConfig);
        
        // Initialize SMTP client with correct configuration for Gmail
        email:SmtpConfiguration smtpConfig = {
            port: smtpPort,
            security: email:START_TLS_AUTO // Enable TLS for Gmail
        };
        self.smtpClient = check new (smtpHost, smtpUsername, smtpPassword, smtpConfig);
        log:printInfo("SMTP client initialized successfully");
    }

    private function hashPassword(string password) returns string|error {
        byte[] hashedBytes = crypto:hashSha256(password.toBytes());
        return hashedBytes.toBase16();
    }

    private function verifyPassword(string password, string hashedPassword) returns boolean|error {
        string hashedInput = check self.hashPassword(password);
        return hashedInput == hashedPassword;
    }

    private function generateVerificationCode() returns string|error {
        // Generate a 6-digit verification code
        int code = check random:createIntInRange(100000, 999999);
        return code.toString();
    }

    private function createUserResponse(User user) returns UserResponse {
        return {
            _id: user?._id,
            username: user.username,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt ?: "",
            isEmailVerified: user.isEmailVerified ?: false
        };
    }

    private function sendVerificationEmail(string email, string verificationCode) {
        log:printInfo(string `Attempting to send verification email to: ${email}`);
        
        email:Message verificationEmail = {
            to: [email],
            subject: "Email Verification - Your App Name",
            body: string `
Hello,

Thank you for registering with our application!

Your email verification code is: ${verificationCode}

This code will expire in 15 minutes. Please use this code to verify your email address.

If you didn't request this verification, please ignore this email.

Best regards,
Your App Team
            `,
            'from: smtpUsername
        };

        do {
            check self.smtpClient->sendMessage(verificationEmail);
            log:printInfo(string `Verification email sent successfully to: ${email}`);
        } on fail error e {
            log:printError(string `Failed to send verification email to ${email}: ${e.message()}`);
        }
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
        string verificationCode = check self.generateVerificationCode();
        
        // Set verification expiry to 15 minutes from now
        time:Utc currentTime = time:utcNow();
        time:Utc expiryTime = time:utcAddSeconds(currentTime, 900); // 15 minutes = 900 seconds
        
        User newUser = {
            username: registerData.username,
            email: registerData.email,
            password: hashedPassword,
            role: registerData.role ?: "user",
            createdAt: time:utcToString(currentTime),
            isEmailVerified: false,
            verificationCode: verificationCode,
            verificationExpiry: time:utcToString(expiryTime)
        };

        json|mongodb:Error result = userCollection->insertOne(newUser);
        if result is mongodb:Error {
            log:printError(string `Failed to create user: ${result.message()}`);
            return error("Failed to create user");
        }
        newUser._id = result;

        log:printInfo(string `User created successfully: ${registerData.username}`);

        // Send verification email
        self.sendVerificationEmail(registerData.email, verificationCode);

        return {
            message: "Registration successful. Please check your email for verification code.",
            user: self.createUserResponse(newUser)
        };
    }

    resource function post verifyemail(VerifyEmailRequest verifyData) returns AuthResponse|http:BadRequest|http:Unauthorized|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        if verifyData.email.length() == 0 || verifyData.verificationCode.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Email and verification code are required"}
            };
        }

        User? user = check userCollection->findOne({email: verifyData.email});
        if user is () {
            return <http:Unauthorized>{
                body: {"message": "User not found"}
            };
        }

        if user?.isEmailVerified == true {
            return <http:BadRequest>{
                body: {"message": "Email is already verified"}
            };
        }

        string storedCode = user?.verificationCode ?: "";
        if storedCode != verifyData.verificationCode {
            return <http:Unauthorized>{
                body: {"message": "Invalid verification code"}
            };
        }

        // Check if verification code has expired
        string? expiryStr = user?.verificationExpiry;
        if expiryStr is string {
            time:Utc|time:Error expiryTime = time:utcFromString(expiryStr);
            if expiryTime is time:Utc {
                time:Utc currentTime = time:utcNow();
                time:Seconds timeDiff = time:utcDiffSeconds(currentTime, expiryTime);
                if timeDiff > 0d {
                    return <http:Unauthorized>{
                        body: {"message": "Verification code has expired"}
                    };
                }
            }
        }

        // Update user to mark email as verified and remove verification code
        mongodb:Update update = {
            set: {
                isEmailVerified: true
            },
            unset: {
                verificationCode: true,
                verificationExpiry: true
            }
        };
        
        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {email: verifyData.email},
            update
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to verify email");
        }

        // Generate JWT token after successful verification
        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": user.role,
                "username": user.username,
                "email": user.email,
                "isEmailVerified": true
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

        user.isEmailVerified = true;
        return {
            message: "Email verified successfully",
            token: token,
            user: self.createUserResponse(user)
        };
    }

    resource function post resend\-verification(@http:Payload json resendData) returns AuthResponse|http:BadRequest|http:NotFound|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        map<json> requestData = <map<json>>resendData;
        string? email = <string?>requestData["email"];
        if email is () || email.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Email is required"}
            };
        }

        User? user = check userCollection->findOne({email: email});
        if user is () {
            return <http:NotFound>{
                body: {"message": "User not found"}
            };
        }

        if user?.isEmailVerified == true {
            return <http:BadRequest>{
                body: {"message": "Email is already verified"}
            };
        }

        string verificationCode = check self.generateVerificationCode();
        time:Utc currentTime = time:utcNow();
        time:Utc expiryTime = time:utcAddSeconds(currentTime, 900); // 15 minutes

        // Update user with new verification code - FIXED syntax
        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {email: email},
            {
                "$set": {
                    "verificationCode": verificationCode,
                    "verificationExpiry": time:utcToString(expiryTime)
                }
            }
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to update verification code");
        }

        // Send new verification email
        self.sendVerificationEmail(email, verificationCode);

        return {
            message: "Verification code resent successfully"
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

        // Check if email is verified
        if user?.isEmailVerified != true {
            return <http:Unauthorized>{
                body: {"message": "Please verify your email before logging in"}
            };
        }

        jwt:IssuerConfig issuerConfig = {
            issuer: jwtIssuer,
            audience: "ballerina-users",
            expTime: 3600,
            customClaims: {
                "role": user.role,
                "username": user.username,
                "email": user.email,
                "isEmailVerified": user?.isEmailVerified
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
            createdAt: time:utcToString(time:utcNow()),
            isEmailVerified: true // Admin is pre-verified
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