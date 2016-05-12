/*
 |  _   ____   ____   _
 | ⎛ |‾|  ⚈ |-| ⚈  |‾| ⎞
 | ⎝ |  ‾‾‾‾| |‾‾‾‾  | ⎠
 |  ‾        ‾        ‾
 */

import Foundation
import Firebase
import ReSwift
import Marshal

/**
 An error that occurred authenticating with Firebase.
 
 - `LogInError`:            The user could not log in
 - `SignUpError`:           The user could not sign up
 - `ChangePasswordError`:   The password for the user could not be changed
 - `ChangeEmailError`:      The email for the user could not be chagned
 - `ResetPasswordError`:    The password for the user could not be reset
 - `LogInMissingUserId`:    The auth payload contained no user id
 - `CurrentUserNotFound`:   The data for the current user could not be found
 */
public enum FirebaseAuthenticationError: ErrorType {
    case LogInError(error: ErrorType)
    case SignUpError(error: ErrorType)
    case ChangePasswordError(error: ErrorType)
    case ChangeEmailError(error: ErrorType)
    case ResetPasswordError(error: ErrorType)
    case LogInMissingUserId
    case CurrentUserNotFound
}

/**
 An action type regarding user authentication
 
 - `UserSignedUp`:      The user successfully signed up
 - `PasswordChanged`:   The password for the user was successfully changed
 - `EmailChanged`:      The email for the user was successfully changed
 - `PasswordReset`:     The user was sent a reset password email
 */
public enum FirebaseAuthenticationAction {
    case UserSignedUp
    case PasswordChanged
    case EmailChanged
    case PasswordReset
}

public extension FirebaseAccess {

    /**
     Attempts to retrieve the user's authentication id. If successful, it is returned
     
     - returns: The user's authentication id, or nil if not authenticated
     */
    public func getUserId() -> String? {
        guard let authData = self.ref.authData, userId = authData.uid else { return nil }
        return userId
    }
    
    /**
     Attempts to load current user information. Passes the JSON data for the current user
     to the completion handler
     
     - Parameters:
        - ref:          A Firebase reference to the current user object
        - completion:   A closure to run after retrieving the current user data and parsing it
     */
    public func getCurrentUser(currentUserRef: Firebase, completion: (userJSON: MarshaledObject?) -> Void) {
        currentUserRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
            guard snapshot.exists() && !(snapshot.value is NSNull) else { completion(userJSON: nil); return }
            guard var json = snapshot.value as? JSONObject else { completion(userJSON: nil); return }
            json["id"] = snapshot.key
            completion(userJSON: json)
        })
    }
    
    /**
     Authenticates the user with email address and password. If successful, dispatches an action
     with the user’s id (`UserLoggedIn`), otherwise dispatches a failed action with an error
     (`UserAuthFailed`).
     
     - Parameters:
        - email:    The user’s email address
        - password: The user’s password
     
     - returns:     An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func logInUser<T: StateType>(email: String, password: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            self.ref.authUser(email, password: password) { error, auth in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.LogInError(error: error)))
                } else if let userId = auth.uid {
                    store.dispatch(UserLoggedIn(userId: userId))
                } else {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.LogInMissingUserId))
                }
            }
            return nil
        }
    }
    
    /**
     Creates a user with the email address and password. On success, an action is dispatched
     to log the user in.
     
     - Parameters:
        - email:    The user’s email address
        - password: The user’s password
     
     - returns:     An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func signUpUser<T: StateType>(email: String, password: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            self.ref.createUser(email, password: password, withValueCompletionBlock: { error, object in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.SignUpError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationAction.UserSignedUp))
                    store.dispatch(self.logInUser(email, password: password))
                }
            })
            return nil
        }
    }
    
    /**
     Change a user’s password.
     
     - Parameters:
        - email:        The user’s email address
        - oldPassword:  The previous password
        - newPassword:  The new password for the user
     
     - returns:         An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func changeUserPassword<T: StateType>(email: String, oldPassword: String, newPassword: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            self.ref.changePasswordForUser(email, fromOld: oldPassword, toNew: newPassword) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ChangePasswordError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationAction.PasswordChanged))
                }
            }
            return ActionCreatorDispatched(dispatchedIn: "changeUserPassword")
        }
    }
    
    /**
     Change a user’s email address.
     
     - Parameters:
        - email:        The user’s previous email address
        - password:     The user’s password
        - newEmail:     The new email address for the user
     
     - returns:         An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func changeUserEmail<T: StateType>(email: String, password: String, newEmail: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            self.ref.changeEmailForUser(email, password: password, toNewEmail: newEmail) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ChangeEmailError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationAction.EmailChanged))
                }
            }
            return ActionCreatorDispatched(dispatchedIn: "changeUserEmail")
        }
    }
    
    /**
     Send the user a reset password email.
     
     - Parameters:
        - email:    The user’s email address
     
     - returns:     An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func resetPassword<T: StateType>(email: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            self.ref.resetPasswordForUser(email) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ResetPasswordError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationAction.PasswordReset))
                }
            }
            return ActionCreatorDispatched(dispatchedIn: "resetPassword")
        }
    }
    
    /**
     Unauthenticates the current user and dispatches a `UserLoggedOut` action.
     
     - returns: An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func logOutUser<T: StateType>(state: T, store: Store<T>) -> Action? {
        ref.unauth()
        store.dispatch(UserLoggedOut())
        return ActionCreatorDispatched(dispatchedIn: "logOutUser")
    }

}


// MARK: - User actions

/**
 Action indicating that the user has just successfully logged in with email and password.
 - Parameter userId: The id of the user
 */
public struct UserLoggedIn: Action {
    public var userId: String
    public init(userId: String) { self.userId = userId }
}

/**
 General action regarding user authentication
 - Parameter action: The authentication action that occurred
 */
public struct UserAuthenticationAction: Action {
    public var action: FirebaseAuthenticationAction
    public init(action: FirebaseAuthenticationAction) { self.action = action }
}

/**
 Action indicating that a failure occurred during authentication.
 - Parameter error: The error that produced the failure
 */
public struct UserAuthFailed: Action {
    public var error: ErrorType
    public init(error: ErrorType) { self.error = error }
}

/**
 Action indicating that the user is properly authenticated.
 - Parameter userId: The id of the authenticated user
 */
public struct UserIdentified: Action {
    public var userId: String
    public init(userId: String) { self.userId = userId }
}

/**
 Action indicating that the user has been unauthenticated.
 */
public struct UserLoggedOut: Action {
    public init() { }
}
