export interface Category {
  _id?: { $oid: string } | string;     // MongoDB ObjectId
  name: string;
  userId?: any;      // stored as object in backend
  links?: string[];
  createdAt?: string;
  updatedAt?: string;
}
