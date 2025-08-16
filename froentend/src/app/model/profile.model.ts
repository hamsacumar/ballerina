export interface User {
  _id?: string;
  username: string;
  email: string;
  role: string;
  createdAt?: string;
  isEmailVerified?: boolean;
  profileImage?: string;
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
  confirmPassword: string;
}
