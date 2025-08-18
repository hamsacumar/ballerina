export interface Link {
  _id?: string;
  name: string;
  hashedUrl: string;
  icon?: string;
  categoryId?: string | null;
  userId?: any;
  createdAt?: string;
  updatedAt?: string;
}
