import ballerina/crypto;
import ballerina/email;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import ballerina/random;
import ballerina/time;
import ballerinax/mongodb;

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
    string? resetCode?;
    string? resetExpiry?;
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

public type ForgotPasswordRequest record {|
    string email;
|};

public type ResetPasswordRequest record {|
    string email;
    string resetCode;
    string newPassword;
|};

public type VerifyCodeRequest record {|
    string email;
    string code;
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
        allowCredentials: true,
        allowHeaders: ["Authorization", "Content-Type"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        exposeHeaders: ["*"],
        maxAge: 3600
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

    private function sendPasswordResetEmail(string email, string resetCode) {
        log:printInfo(string `Attempting to send password reset email to: ${email}`);

        email:Message resetEmail = {
            to: [email],
            subject: "Password Reset Request - Your App Name",
            body: string `
Hello,

We received a request to reset your password for your account.

Your password reset code is: ${resetCode}

This code will expire in 15 minutes. Please use this code to reset your password.

If you didn't request this password reset, please ignore this email and your password will remain unchanged.

For security reasons, please do not share this code with anyone.

Best regards,
Your App Team
            `,
            'from: smtpUsername
        };

        do {
            check self.smtpClient->sendMessage(resetEmail);
            log:printInfo(string `Password reset email sent successfully to: ${email}`);
        } on fail error e {
            log:printError(string `Failed to send password reset email to ${email}: ${e.message()}`);
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

    resource function post forgotpassword(ForgotPasswordRequest forgotData) returns AuthResponse|http:BadRequest|http:NotFound|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");

        if forgotData.email.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Email is required"}
            };
        }

        User? user = check userCollection->findOne({email: forgotData.email});
        if user is () {
            // For security reasons, don't reveal if email exists or not
            return {
                message: "If an account with this email exists, a password reset code has been sent."
            };
        }

        string resetCode = check self.generateVerificationCode();
        time:Utc currentTime = time:utcNow();
        time:Utc expiryTime = time:utcAddSeconds(currentTime, 900); // 15 minutes

        // Update user with reset code and expiry
        mongodb:Update update = {
            set: {
                resetCode: resetCode,
                resetExpiry: time:utcToString(expiryTime)
            }
        };

        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {email: forgotData.email},
            update
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to update reset code");
        }

        // Send password reset email
        self.sendPasswordResetEmail(forgotData.email, resetCode);

        log:printInfo(string `Password reset requested for email: ${forgotData.email}`);

        return {
            message: "If an account with this email exists, a password reset code has been sent."
        };
    }

    resource function post resetpassword(ResetPasswordRequest resetData) returns AuthResponse|http:BadRequest|http:Unauthorized|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");

        if resetData.email.length() == 0 || resetData.resetCode.length() == 0 || resetData.newPassword.length() == 0 {
            return <http:BadRequest>{
                body: {"message": "Email, reset code, and new password are required"}
            };
        }

        if resetData.newPassword.length() < 6 {
            return <http:BadRequest>{
                body: {"message": "New password must be at least 6 characters long"}
            };
        }

        User? user = check userCollection->findOne({email: resetData.email});
        if user is () {
            return <http:Unauthorized>{
                body: {"message": "Invalid reset request"}
            };
        }

        string storedResetCode = user?.resetCode ?: "";
        if storedResetCode != resetData.resetCode {
            return <http:Unauthorized>{
                body: {"message": "Invalid reset code"}
            };
        }

        // Check if reset code has expired
        string? resetExpiryStr = user?.resetExpiry;
        if resetExpiryStr is string {
            time:Utc|time:Error expiryTime = time:utcFromString(resetExpiryStr);
            if expiryTime is time:Utc {
                time:Utc currentTime = time:utcNow();
                time:Seconds timeDiff = time:utcDiffSeconds(currentTime, expiryTime);
                if timeDiff > 0d {
                    return <http:Unauthorized>{
                        body: {"message": "Reset code has expired"}
                    };
                }
            }
        }

        // Hash the new password
        string hashedNewPassword = check self.hashPassword(resetData.newPassword);

        // Update user password and remove reset code
        mongodb:Update update = {
            set: {
                password: hashedNewPassword
            },
            unset: {
                resetCode: true,
                resetExpiry: true
            }
        };

        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {email: resetData.email},
            update
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to reset password");
        }

        log:printInfo(string `Password reset successfully for email: ${resetData.email}`);

        return {
            message: "Password reset successfully. You can now login with your new password."
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
            username: "Logasini",
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

    // Fixed Update username endpoint
    resource function put update\-username(@http:Header string Authorization, @http:Payload json updateData)
        returns json|http:BadRequest|http:Unauthorized|http:Forbidden|error {

        // Authenticate and authorize user
        jwt:Payload|http:Unauthorized authn = self.jwtHandler.authenticate(Authorization);
        if authn is http:Unauthorized {
            return authn;
        }

        http:Forbidden? authz = self.jwtHandler.authorize(<jwt:Payload>authn, ["admin", "user"]);
        if authz is http:Forbidden {
            return authz;
        }

        jwt:Payload payload = <jwt:Payload>authn;
        string? currentUsername = <string?>payload["username"];

        if currentUsername is () {
            return error("Invalid token: missing username");
        }

        map<json> requestData = <map<json>>updateData;
        string? newUsername = <string?>requestData["newUsername"];

        if newUsername is () || newUsername.length() < 3 {
            return <http:BadRequest>{
                body: {"message": "Username must be at least 3 characters long"}
            };
        }

        mongodb:Collection userCollection = check myDb->getCollection("users");

        // Check if new username already exists
        User? existingUser = check userCollection->findOne({username: newUsername});
        if existingUser is User && existingUser.username != currentUsername {
            return <http:BadRequest>{
                body: {"message": "Username already exists"}
            };
        }

        // FIXED: Update username using mongodb:Update record
        mongodb:Update update = {
            set: {
                username: newUsername
            }
        };
        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {username: currentUsername},
            update
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to update username");
        }

        return {"message": "Username updated successfully"};
    }

    // Fixed Update password endpoint
    resource function put update\-password(@http:Header string Authorization, @http:Payload json passwordData)
        returns json|http:BadRequest|http:Unauthorized|http:Forbidden|error {

        // Authenticate and authorize user
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

        map<json> requestData = <map<json>>passwordData;
        string? oldPassword = <string?>requestData["oldPassword"];
        string? newPassword = <string?>requestData["newPassword"];
        string? confirmPassword = <string?>requestData["confirmPassword"];

        if oldPassword is () || newPassword is () || confirmPassword is () {
            return <http:BadRequest>{
                body: {"message": "Old password, new password, and confirmation are required"}
            };
        }

        if newPassword != confirmPassword {
            return <http:BadRequest>{
                body: {"message": "New passwords do not match"}
            };
        }

        if newPassword.length() < 6 {
            return <http:BadRequest>{
                body: {"message": "New password must be at least 6 characters long"}
            };
        }

        mongodb:Collection userCollection = check myDb->getCollection("users");
        User? user = check userCollection->findOne({username: username});

        if user is () {
            return <http:Unauthorized>{
                body: {"message": "User not found"}
            };
        }

        // Verify old password
        string userPassword = user.password ?: "";
        boolean isValidPassword = check self.verifyPassword(oldPassword, userPassword);
        if !isValidPassword {
            return <http:Unauthorized>{
                body: {"message": "Current password is incorrect"}
            };
        }

        // Hash new password
        string hashedNewPassword = check self.hashPassword(newPassword);

        // FIXED: Update password using mongodb:Update record
        mongodb:Update update = {
            set: {
                password: hashedNewPassword
            }
        };
        mongodb:UpdateResult updateResult = check userCollection->updateOne(
            {username: username},
            update
        );

        if updateResult.modifiedCount == 0 {
            return error("Failed to update password");
        }

        return {"message": "Password updated successfully"};
    }

    // Add this logout resource function to your existing service

    resource function post logout(@http:Header string Authorization)
        returns json|http:Unauthorized|http:Forbidden|error {

        // Authenticate the user to ensure they have a valid token
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

        log:printInfo(string `User ${username} logged out successfully`);

        return {
            "message": "Logout successful",
            "timestamp": time:utcNow()
        };
    }
}
