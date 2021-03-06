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

/// Empty protocol to help categorize actions
public protocol FirebaseAuthenticationAction: Action { }

/**
 An error that occurred authenticating with Firebase.
 
 - `LogInError`:            The user could not log in
 - `SignUpError`:           The user could not sign up
 - `ChangePasswordError`:   The password for the user could not be changed
 - `ChangeEmailError`:      The email for the user could not be chagned
 - `ResetPasswordError`:    The password for the user could not be reset
 - `LogInMissingUserId`:    The auth payload contained no user id
 - `SignUpFailedLogIn`:     The user was signed up, but could not be logged in
 - `CurrentUserNotFound`:   The data for the current user could not be found
 */
public enum FirebaseAuthenticationError: ErrorType {
    case LogInError(error: ErrorType)
    case SignUpError(error: ErrorType)
    case ChangePasswordError(error: ErrorType)
    case ChangeEmailError(error: ErrorType)
    case ResetPasswordError(error: ErrorType)
    case LogOutError(error: ErrorType)
    case LogInMissingUserId
    case SignUpFailedLogIn
    case CurrentUserNotFound
}

/**
 An event type regarding user authentication
 
 - `UserSignedUp`:      The user successfully signed up
 - `PasswordChanged`:   The password for the user was successfully changed
 - `EmailChanged`:      The email for the user was successfully changed
 - `PasswordReset`:     The user was sent a reset password email
 */
public enum FirebaseAuthenticationEvent {
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
        guard let user = FIRAuth.auth()?.currentUser else { return nil }
        return user.uid
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
            FIRAuth.auth()?.signInWithEmail(email, password: password) { user, error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.LogInError(error: error)))
                } else if let user = user {
                    store.dispatch(UserLoggedIn(userId: user.uid))
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
            FIRAuth.auth()?.createUserWithEmail(email, password: password) { user, error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.SignUpError(error: error)))
                } else if let user = user {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationEvent.UserSignedUp))
                    store.dispatch(UserLoggedIn(userId: user.uid))
                } else {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.SignUpFailedLogIn))
                }
            }
            return nil
        }
    }
    
    /**
     Change a user’s password.
     
     - Parameters:
        - newPassword:  The new password for the user
     
     - returns:         An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func changeUserPassword<T: StateType>(newPassword: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            guard let user = FIRAuth.auth()?.currentUser else {
                store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.CurrentUserNotFound))
                return nil
            }
            user.updatePassword(newPassword) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ChangePasswordError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationEvent.PasswordChanged))
                }
            }
            return nil
        }
    }
    
    /**
     Change a user’s email address.
     
     - Parameters:
        - email:        The new email address for the user
     
     - returns:         An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func changeUserEmail<T: StateType>(email: String) -> (state: T, store: Store<T>) -> Action? {
        return { state, store in
            guard let user = FIRAuth.auth()?.currentUser else {
                store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.CurrentUserNotFound))
                return nil
            }
            user.updateEmail(email) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ChangeEmailError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationEvent.EmailChanged))
                }
            }
            return nil
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
            FIRAuth.auth()?.sendPasswordResetWithEmail(email) { error in
                if let error = error {
                    store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.ResetPasswordError(error: error)))
                } else {
                    store.dispatch(UserAuthenticationAction(action: FirebaseAuthenticationEvent.PasswordReset))
                }
            }
            return nil
        }
    }
    
    /**
     Unauthenticates the current user and dispatches a `UserLoggedOut` action.
     
     - returns: An `ActionCreator` (`(state: StateType, store: StoreType) -> Action?`) whose
     type matches the state type associated with the store on which it is dispatched.
     */
    public func logOutUser<T: StateType>(state: T, store: Store<T>) -> Action? {
        do {
            try FIRAuth.auth()?.signOut()
            store.dispatch(UserLoggedOut())
        } catch {
            store.dispatch(UserAuthFailed(error: FirebaseAuthenticationError.LogOutError(error: error)))
        }
        return nil
    }

}


// MARK: - User actions

/**
 Action indicating that the user has just successfully logged in with email and password.
 - Parameter userId: The id of the user
 */
public struct UserLoggedIn: Action, FirebaseAuthenticationAction {
    public var userId: String
    public init(userId: String) { self.userId = userId }
}

/**
 General action regarding user authentication
 - Parameter action: The authentication action that occurred
 */
public struct UserAuthenticationAction: Action, FirebaseAuthenticationAction {
    public var action: FirebaseAuthenticationEvent
    public init(action: FirebaseAuthenticationEvent) { self.action = action }
}

/**
 Action indicating that a failure occurred during authentication.
 - Parameter error: The error that produced the failure
 */
public struct UserAuthFailed: Action, FirebaseSeriousErrorAction {
    public var error: ErrorType
    public init(error: ErrorType) { self.error = error }
}

/**
 Action indicating that the user is properly authenticated.
 - Parameter userId: The id of the authenticated user
 */
public struct UserIdentified: Action, FirebaseAuthenticationAction {
    public var userId: String
    public init(userId: String) { self.userId = userId }
}

/**
 Action indicating that the user has been unauthenticated.
 */
public struct UserLoggedOut: Action, FirebaseAuthenticationAction {
    public init() { }
}
