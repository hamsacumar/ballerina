import ballerina/http;
import ballerinax/mongodb;
import ballerina/time;

// MongoDB connection is already established in main configuration
// Using the existing myDb instance from the main configuration

// Type definitions
public type Category record {|
    json _id?;
    string name;
    string userId;
    string[] links?; // Array of link IDs
    string createdAt?;
    string updatedAt?;
|};

public type Link record {|
    json _id?;
    string name;
    string url;
    string icon?;
    string categoryId;
    string userId;
    string createdAt?;
    string updatedAt?;
|};

public type CategoryRequest record {|
    string name;
    string userId;
|};

public type LinkRequest record {|
    string name;
    string url;
    string categoryId;
    string userId;
|};

public type CategoryUpdate record {|
    string name;
|};

public type LinkUpdate record {|
    string? name?;
    string? url?;
    string? categoryId?;
|};

public type SearchResult record {|
    Link[] links;
    Category[] categories;
|};

public type IconUpdateRequest record {|
    string iconUrl;
|};

// Error responses
public type ErrorResponse record {|
    string message;
    int code?;
|};

// CORS configuration for Angular frontend
@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /api on new http:Listener(9094) {

    // Utility function to extract domain from URL
    private function extractDomain(string inputUrl) returns string|error {
        // Clean the URL - remove protocol if present
        string cleanUrl = inputUrl;
        if (cleanUrl.startsWith("http://")) {
            cleanUrl = cleanUrl.substring(7);
        } else if (cleanUrl.startsWith("https://")) {
            cleanUrl = cleanUrl.substring(8);
        }
        
        // Remove path and query parameters
        int? slashIndex = cleanUrl.indexOf("/");
        if (slashIndex is int && slashIndex > 0) {
            cleanUrl = cleanUrl.substring(0, slashIndex);
        }
        
        // Remove port if present
        int? colonIndex = cleanUrl.indexOf(":");
        if (colonIndex is int && colonIndex > 0) {
            cleanUrl = cleanUrl.substring(0, colonIndex);
        }
        
        return cleanUrl;
    }

    // Utility function to generate favicon URL
    private function generateFaviconUrl(string websiteUrl) returns string {
        string|error domain = self.extractDomain(websiteUrl);
        if (domain is error) {
            return "https://www.google.com/s2/favicons?domain=default";
        }
        return string `https://www.google.com/s2/favicons?domain=${domain}`;
    }

    // Health check endpoint
    resource function get health() returns json {
        return {"status": "healthy", "service": "link-saver", "timestamp": time:utcNow()};
    }

    // =============== CATEGORY CRUD OPERATIONS ===============

    // Create a new category
    resource function post categories(CategoryRequest categoryData) returns json|http:BadRequest|http:InternalServerError|error {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Validate input
        if (categoryData.name.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "Category name cannot be empty"}
            };
        }

        // Check if category with same name exists for this user
        Category|error existingCategory = check categoryCollection->findOne({
            name: categoryData.name,
            userId: categoryData.userId
        });
        
        if (existingCategory is Category) {
            return <http:BadRequest>{
                body: {"message": "Category with this name already exists"}
            };
        }

        // Create new category
        Category newCategory = {
            name: categoryData.name.trim(),
            userId: categoryData.userId,
            links: [],
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        error? insertResult = categoryCollection->insertOne(newCategory);
        if (insertResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to create category"}
            };
        }

        return {
            "message": "Category created successfully",
            "category": newCategory
        };
    }

    // Get all categories for a user
    resource function get categories/[string userId]() returns Category[]|http:InternalServerError {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        stream<Category, error?> categoryStream = check categoryCollection->find({userId: userId});
        Category[] categories = [];
        
        error? collectResult = categoryStream.forEach(function(Category category) {
            categories.push(category);
        });
        
        if (collectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve categories"}
            };
        }
        
        return categories;
    }

    // Update a category
    resource function put categories/[string categoryId](CategoryUpdate updateData) returns json|http:BadRequest|http:NotFound|http:InternalServerError {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Validate input
        if (updateData.name.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "Category name cannot be empty"}
            };
        }

        // Check if category exists
        Category|error existingCategory = categoryCollection->findOne({_id: categoryId});
        if (existingCategory is error || existingCategory is ()) {
            return <http:NotFound>{
                body: {"message": "Category not found"}
            };
        }

        // Update category
        mongodb:Update updateOperation = {
            set: {
                name: updateData.name.trim(),
                updatedAt: time:utcToString(time:utcNow())
            }
        };

        mongodb:UpdateResult|error updateResult = categoryCollection->updateOne(
            {_id: categoryId},
            updateOperation
        );

        if (updateResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to update category"}
            };
        }

        return {"message": "Category updated successfully"};
    }

    // Delete a category
    resource function delete categories/[string categoryId]() returns json|http:NotFound|http:InternalServerError {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        // Check if category exists
        Category|error existingCategory = categoryCollection->findOne({_id: categoryId});
        if (existingCategory is error || existingCategory is ()) {
            return <http:NotFound>{
                body: {"message": "Category not found"}
            };
        }

        // Delete all links in this category
        mongodb:DeleteResult|error linkDeleteResult = linkCollection->deleteMany({categoryId: categoryId});
        if (linkDeleteResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to delete associated links"}
            };
        }

        // Delete the category
        mongodb:DeleteResult|error categoryDeleteResult = categoryCollection->deleteOne({_id: categoryId});
        if (categoryDeleteResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to delete category"}
            };
        }

        return {"message": "Category and associated links deleted successfully"};
    }

    // =============== LINK CRUD OPERATIONS ===============

    // Create a new link
    resource function post links(LinkRequest linkData) returns json|http:BadRequest|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Validate input
        if (linkData.name.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "Link name cannot be empty"}
            };
        }

        if (linkData.url.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "URL cannot be empty"}
            };
        }

        // Validate URL format
        string cleanUrl = linkData.url.trim();
        if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
            cleanUrl = "https://" + cleanUrl;
        }

        // Check if category exists
        Category|error category = categoryCollection->findOne({_id: linkData.categoryId});
        if (category is error || category is ()) {
            return <http:BadRequest>{
                body: {"message": "Category not found"}
            };
        }

        // Generate favicon URL
        string iconUrl = self.generateFaviconUrl(cleanUrl);

        // Create new link
        Link newLink = {
            name: linkData.name.trim(),
            url: cleanUrl,
            icon: iconUrl,
            categoryId: linkData.categoryId,
            userId: linkData.userId,
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        error? insertResult = linkCollection->insertOne(newLink);
        if (insertResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to create link"}
            };
        }

        return {
            "message": "Link created successfully",
            "link": newLink
        };
    }

    // Get all links for a user
    resource function get links/[string userId]() returns Link[]|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        stream<Link, error?> linkStream = check linkCollection->find({userId: userId});
        Link[] links = [];
        
        error? collectResult = linkStream.forEach(function(Link link) {
            links.push(link);
        });
        
        if (collectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve links"}
            };
        }
        
        return links;
    }

    // Get links by category
    resource function get links/category/[string categoryId]() returns Link[]|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        stream<Link, error?> linkStream = check linkCollection->find({categoryId: categoryId});
        Link[] links = [];
        
        error? collectResult = linkStream.forEach(function(Link link) {
            links.push(link);
        });
        
        if (collectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve links"}
            };
        }
        
        return links;
    }

    // Update a link
    resource function put links/[string linkId](LinkUpdate updateData) returns json|http:BadRequest|http:NotFound|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Check if link exists
        Link|error existingLink = linkCollection->findOne({_id: linkId});
        if (existingLink is error || existingLink is ()) {
            return <http:NotFound>{
                body: {"message": "Link not found"}
            };
        }

        // Prepare update fields
        map<json> updateFields = {
            updatedAt: time:utcToString(time:utcNow())
        };

        // Validate and add name if provided
        if (updateData?.name is string) {
            string name = <string>updateData?.name;
            if (name.trim().length() == 0) {
                return <http:BadRequest>{
                    body: {"message": "Link name cannot be empty"}
                };
            }
            updateFields["name"] = name.trim();
        }

        // Validate and add URL if provided
        if (updateData?.url is string) {
            string inputUrl = <string>updateData?.url;
            if (inputUrl.trim().length() == 0) {
                return <http:BadRequest>{
                    body: {"message": "URL cannot be empty"}
                };
            }
            
            string cleanUrl = inputUrl.trim();
            if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
                cleanUrl = "https://" + cleanUrl;
            }
            
            updateFields["url"] = cleanUrl;
            updateFields["icon"] = self.generateFaviconUrl(cleanUrl);
        }

        // Validate and add category if provided
        if (updateData?.categoryId is string) {
            string categoryId = <string>updateData?.categoryId;
            Category|error category = categoryCollection->findOne({_id: categoryId});
            if (category is error || category is ()) {
                return <http:BadRequest>{
                    body: {"message": "Category not found"}
                };
            }
            updateFields["categoryId"] = categoryId;
        }

        // Update link
        mongodb:Update updateOperation = {
            set: updateFields
        };

        mongodb:UpdateResult|error updateResult = linkCollection->updateOne(
            {_id: linkId},
            updateOperation
        );

        if (updateResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to update link"}
            };
        }

        return {"message": "Link updated successfully"};
    }

    // Delete a link
    resource function delete links/[string linkId]() returns json|http:NotFound|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        // Check if link exists
        Link|error existingLink = linkCollection->findOne({_id: linkId});
        if (existingLink is error || existingLink is ()) {
            return <http:NotFound>{
                body: {"message": "Link not found"}
            };
        }

        // Delete the link
        mongodb:DeleteResult|error deleteResult = linkCollection->deleteOne({_id: linkId});
        if (deleteResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to delete link"}
            };
        }

        return {"message": "Link deleted successfully"};
    }

    // =============== SEARCH FUNCTIONALITY ===============

    // Search links and categories
    resource function get search(string query, string userId) returns SearchResult|http:BadRequest|http:InternalServerError {
        if (query.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "Search query cannot be empty"}
            };
        }

        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        string searchQuery = query.trim().toLowerAscii();
        
        // Search links by name or URL (case-insensitive)
        map<json> linkFilter = {
            userId: userId,
            "$or": [
                {"name": {"$regex": searchQuery, "$options": "i"}},
                {"url": {"$regex": searchQuery, "$options": "i"}}
            ]
        };

        stream<Link, error?> linkStream = check linkCollection->find(linkFilter);
        Link[] foundLinks = [];
        
        error? linkCollectResult = linkStream.forEach(function(Link link) {
            foundLinks.push(link);
        });
        
        if (linkCollectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to search links"}
            };
        }

        // Search categories by name (case-insensitive)
        map<json> categoryFilter = {
            userId: userId,
            "name": {"$regex": searchQuery, "$options": "i"}
        };

        stream<Category, error?> categoryStream = check categoryCollection->find(categoryFilter);
        Category[] foundCategories = [];
        
        error? categoryCollectResult = categoryStream.forEach(function(Category category) {
            foundCategories.push(category);
        });
        
        if (categoryCollectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to search categories"}
            };
        }

        return {
            links: foundLinks,
            categories: foundCategories
        };
    }

    // =============== ADDITIONAL UTILITY ENDPOINTS ===============

    // Get a single category by ID
    resource function get categories/single/[string categoryId]() returns Category|http:NotFound|http:InternalServerError {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        Category|error category = categoryCollection->findOne({_id: categoryId});
        if (category is error || category is ()) {
            return <http:NotFound>{
                body: {"message": "Category not found"}
            };
        }

        return category;
    }

    // Get a single link by ID
    resource function get links/single/[string linkId]() returns Link|http:NotFound|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        Link|error link = linkCollection->findOne({_id: linkId});
        if (link is error || link is ()) {
            return <http:NotFound>{
                body: {"message": "Link not found"}
            };
        }

        return link;
    }

    // Get links with category information (populated)
    resource function get links/populated/[string userId]() returns json[]|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Get all links for user
        stream<Link, error?> linkStream = check linkCollection->find({userId: userId});
        json[] populatedLinks = [];
        
        error? processResult = linkStream.forEach(function(Link link) {
            // Get category information
            Category|error category = categoryCollection->findOne({_id: link.categoryId});
            
            json populatedLink = {
                "_id": link?._id,
                "name": link.name,
                "url": link.url,
                "icon": link?.icon,
                "categoryId": link.categoryId,
                "userId": link.userId,
                "createdAt": link?.createdAt,
                "updatedAt": link?.updatedAt,
                "category": category is Category ? {"_id": category?._id, "name": category.name} : ()
            };
            
            populatedLinks.push(populatedLink);
        });
        
        if (processResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve populated links"}
            };
        }
        
        return populatedLinks;
    }

    // Get categories with link count
    resource function get categories/withcount/[string userId]() returns json[]|http:InternalServerError {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        stream<Category, error?> categoryStream = check categoryCollection->find({userId: userId});
        json[] categoriesWithCount = [];
        
        error? processResult = categoryStream.forEach(function(Category category) {
            // Count links in this category
            int|error linkCount = linkCollection->countDocuments({categoryId: category?._id.toString()});
            
            json categoryWithCount = {
                "_id": category?._id,
                "name": category.name,
                "userId": category.userId,
                "createdAt": category?.createdAt,
                "updatedAt": category?.updatedAt,
                "linkCount": linkCount is int ? linkCount : 0
            };
            
            categoriesWithCount.push(categoryWithCount);
        });
        
        if (processResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve categories with count"}
            };
        }
        
        return categoriesWithCount;
    }

    // Bulk delete links
    resource function delete links/bulk(string[] linkIds) returns json|http:BadRequest|http:InternalServerError {
        if (linkIds.length() == 0) {
            return <http:BadRequest>{
                body: {"message": "No link IDs provided"}
            };
        }

        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        map<json> deleteFilter = {
            "_id": {"$in": linkIds}
        };

        mongodb:DeleteResult|error deleteResult = linkCollection->deleteMany(deleteFilter);
        if (deleteResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to delete links"}
            };
        }

        mongodb:DeleteResult result = <mongodb:DeleteResult>deleteResult;
        return {
            "message": "Links deleted successfully",
            "deletedCount": result.deletedCount
        };
    }

    // Update link icon manually (in case automatic fetch fails)
    resource function put links/[string linkId]/icon(IconUpdateRequest iconData) returns json|http:BadRequest|http:NotFound|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        // Validate input
        if (iconData.iconUrl.trim().length() == 0) {
            return <http:BadRequest>{
                body: {"message": "Icon URL is required"}
            };
        }

        // Check if link exists
        Link|error existingLink = linkCollection->findOne({_id: linkId});
        if (existingLink is error || existingLink is ()) {
            return <http:NotFound>{
                body: {"message": "Link not found"}
            };
        }

        // Update icon
        mongodb:Update updateOperation = {
            set: {
                icon: iconData.iconUrl.trim(),
                updatedAt: time:utcToString(time:utcNow())
            }
        };

        mongodb:UpdateResult|error updateResult = linkCollection->updateOne(
            {_id: linkId},
            updateOperation
        );

        if (updateResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to update icon"}
            };
        }

        return {"message": "Icon updated successfully"};
    }

    // Get statistics for user
    resource function get stats/[string userId]() returns json|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        int|error totalLinks = linkCollection->countDocuments({userId: userId});
        int|error totalCategories = categoryCollection->countDocuments({userId: userId});
        
        if (totalLinks is error || totalCategories is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve statistics"}
            };
        }

        return {
            "totalLinks": totalLinks,
            "totalCategories": totalCategories,
            "timestamp": time:utcToString(time:utcNow())
        };
    }

    // Export all user data
    resource function get export/[string userId]() returns json|http:InternalServerError {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Get all categories
        stream<Category, error?> categoryStream = check categoryCollection->find({userId: userId});
        Category[] categories = [];
        
        error? categoryCollectResult = categoryStream.forEach(function(Category category) {
            categories.push(category);
        });
        
        if (categoryCollectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to export categories"}
            };
        }

        // Get all links
        stream<Link, error?> linkStream = check linkCollection->find({userId: userId});
        Link[] links = [];
        
        error? linkCollectResult = linkStream.forEach(function(Link link) {
            links.push(link);
        });
        
        if (linkCollectResult is error) {
            return <http:InternalServerError>{
                body: {"message": "Failed to export links"}
            };
        }

        return {
            "exportDate": time:utcToString(time:utcNow()),
            "userId": userId,
            "categories": categories,
            "links": links
        };
    }
}