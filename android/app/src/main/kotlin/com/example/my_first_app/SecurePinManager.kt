package com.example.my_first_app

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Secure PIN manager using EncryptedSharedPreferences backed by Android Keystore.
 * Stores only hashed PIN, never plaintext.
 */
class SecurePinManager(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "secure_pin_prefs"
        private const val KEY_PIN_HASH = "pin_hash"
        private const val KEY_PIN_SALT = "pin_salt"
        private const val HASH_ALGORITHM = "SHA-256"
        private const val KEYSTORE_ALIAS = "pin_manager_key"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEYSET_KEY_NAME = "pin_encryption_keyset"
    }

    private val encryptedPrefs: SharedPreferences by lazy {
        createEncryptedSharedPreferences()
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        // Check if key already exists
        keyStore.getKey(KEYSTORE_ALIAS, null)?.let {
            return it as SecretKey
        }

        // Create new key
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )

        val keyGenSpec = KeyGenParameterSpec.Builder(
            KEYSTORE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        keyGenerator.init(keyGenSpec)
        return keyGenerator.generateKey()
    }

    private fun createEncryptedSharedPreferences(): SharedPreferences {
        return EncryptedSharedPreferences.create(
            PREFS_NAME,
            KEYSET_KEY_NAME,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /**
     * Check if a PIN has been set.
     * @return true if PIN exists, false otherwise
     */
    fun isPinSet(): Boolean {
        return encryptedPrefs.contains(KEY_PIN_HASH)
    }

    /**
     * Set a new PIN. This will overwrite any existing PIN.
     * @param newPin The PIN to set (will be hashed before storage)
     * @return true if PIN was successfully set, false otherwise
     */
    fun setPin(newPin: String): Boolean {
        if (newPin.isBlank()) {
            return false
        }

        if (newPin.length < 4) {
            return false
        }

        return try {
            val salt = generateSalt()
            val hash = hashPin(newPin, salt)

            encryptedPrefs.edit()
                .putString(KEY_PIN_HASH, hash)
                .putString(KEY_PIN_SALT, salt)
                .apply()

            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Verify an input PIN against the stored hash.
     * @param inputPin The PIN to verify
     * @return true if PIN matches, false otherwise
     */
    fun verifyPin(inputPin: String): Boolean {
        if (inputPin.isBlank() || !isPinSet()) {
            return false
        }

        val storedHash = encryptedPrefs.getString(KEY_PIN_HASH, null) ?: return false
        val salt = encryptedPrefs.getString(KEY_PIN_SALT, null) ?: return false

        val inputHash = hashPin(inputPin, salt)
        return storedHash == inputHash
    }

    /**
     * Clear the stored PIN. Use with caution - this cannot be undone.
     */
    fun clearPin() {
        encryptedPrefs.edit()
            .remove(KEY_PIN_HASH)
            .remove(KEY_PIN_SALT)
            .apply()
    }

    private fun generateSalt(): String {
        val saltBytes = ByteArray(16)
        java.security.SecureRandom().nextBytes(saltBytes)
        return bytesToHex(saltBytes)
    }

    private fun hashPin(pin: String, salt: String): String {
        val digest = MessageDigest.getInstance(HASH_ALGORITHM)
        val saltedPin = salt + pin
        val hashBytes = digest.digest(saltedPin.toByteArray(Charsets.UTF_8))
        return bytesToHex(hashBytes)
    }

    private fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString("") { "%02x".format(it) }
    }
}

