"""
=============================================================================
NaariRakshak — Scream Detection Model Training Pipeline (V2 - Raw Audio)
=============================================================================
Pipeline:
  1. Scan dataset folders → build file manifest with labels
  2. Preprocess: resample → mono → 3-second chunks (No Spectrograms!)
  3. Train / Val / Test Split: 70 / 15 / 15
  4. Train 1D CNN model directly on raw audio waves (66150, 1)
  5. Evaluate: confusion matrix, classification report, ROC-AUC
  6. Export to TFLite → assets/scream_detector.tflite

Requirements (install before running):
  pip install tensorflow librosa numpy pandas scikit-learn matplotlib seaborn tqdm soundfile

Run:
  python ml/train_scream_detector_v2.py
=============================================================================
"""

import os
import sys
import json
import warnings
import numpy as np
import pandas as pd
import librosa
import matplotlib.pyplot as plt
import seaborn as sns
import tensorflow as tf
from pathlib import Path
from tqdm import tqdm
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score, roc_curve

warnings.filterwarnings("ignore")

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
CFG = {
    "sample_rate": 8000,          # Hz (Reduced to prevent Out of Memory)
    "clip_duration": 3.0,          # seconds per chunk
    "audio_length": int(8000 * 3.0), # 24000 samples
    
    "batch_size": 32,
    "epochs": 40,
    "learning_rate": 1e-3,
    "early_stopping_patience": 8,

    # Paths
    "dataset_root": r"D:\naarirakshak\dataset",
    "output_dir": r"D:\naarirakshak\ml\output_v2",
    "tflite_output": r"D:\naarirakshak\assets\scream_detector.tflite",
}

LABEL_MAP = {
    r"archive\Screaming":                          1,
    r"archive (1)\Converted_Separately\scream":    1,
    r"archive (2)":                                1,
    r"archive\NotScreaming":                       0,
    r"archive (1)\Converted_Separately\non_scream":0,
}

AUDIO_EXTENSIONS = {".wav", ".mp3", ".aiff", ".aif", ".ogg", ".flac", ".m4a"}

os.makedirs(CFG["output_dir"], exist_ok=True)
os.makedirs(os.path.dirname(CFG["tflite_output"]), exist_ok=True)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — SCAN DATASET FOLDERS
# ─────────────────────────────────────────────────────────────────────────────
def scan_dataset() -> pd.DataFrame:
    print("\n" + "=" * 60)
    print("STEP 1: Scanning dataset folders…")
    print("=" * 60)

    records = []
    for rel_folder, label in LABEL_MAP.items():
        folder = Path(CFG["dataset_root"]) / rel_folder
        if not folder.exists():
            continue

        files = [f for f in folder.rglob("*") if f.suffix.lower() in AUDIO_EXTENSIONS]
        print(f"  {'SCREAM' if label == 1 else 'NON-SCREAM':12} | {len(files):5,} files | {rel_folder}")

        for f in files:
            records.append({"filepath": str(f), "label": label,
                            "label_name": "scream" if label == 1 else "not_scream"})

    df = pd.DataFrame(records).drop_duplicates(subset="filepath")
    print(f"\n  Total files found: {len(df):,}")
    return df


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — RAW AUDIO EXTRACTION
# ─────────────────────────────────────────────────────────────────────────────
def extract_raw_audio(filepath: str) -> list[np.ndarray]:
    clip_len = CFG["audio_length"]

    try:
        y, sr = librosa.load(filepath, sr=CFG["sample_rate"], mono=True)
    except Exception:
        return []

    y = librosa.util.normalize(y)

    chunks = []
    step = clip_len // 2  # 50% overlap
    if len(y) < clip_len:
        y = np.pad(y, (0, clip_len - len(y)))
        chunks = [y.astype(np.float32)]
    else:
        for start in range(0, len(y) - clip_len + 1, step):
            chunks.append(y[start: start + clip_len].astype(np.float32))

    return chunks

def build_feature_arrays(df: pd.DataFrame, cache_path: str) -> tuple[np.ndarray, np.ndarray]:
    if os.path.exists(cache_path):
        print(f"\n  ✅ Loading cached features from {cache_path}")
        data = np.load(cache_path)
        return data["X"], data["y"]

    print("\n" + "=" * 60)
    print("STEP 2: Extracting raw audio arrays…")
    print("=" * 60)

    X_list, y_list = [], []
    
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Processing"):
        chunks = extract_raw_audio(row["filepath"])
        for chunk in chunks:
            X_list.append(chunk)
            y_list.append(row["label"])

    X = np.array(X_list)[..., np.newaxis]  # → (N, 66150, 1)
    y = np.array(y_list)

    np.savez_compressed(cache_path, X=X, y=y)
    return X, y


# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — TRAIN / VAL / TEST SPLIT
# ─────────────────────────────────────────────────────────────────────────────
def split_data(X: np.ndarray, y: np.ndarray):
    print("\n" + "=" * 60)
    print("STEP 3: Train / Val / Test Split")
    print("=" * 60)
    
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=0.30, random_state=42, stratify=y
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.50, random_state=42, stratify=y_temp
    )
    return X_train, X_val, X_test, y_train, y_val, y_test


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — 1D CNN MODEL
# ─────────────────────────────────────────────────────────────────────────────
def build_model() -> tf.keras.Model:
    layers = tf.keras.layers
    models = tf.keras.models

    inp = layers.Input(shape=(CFG["audio_length"], 1), name="raw_audio_input")

    # 1D CNN for raw waveform
    x = layers.Conv1D(16, 8, strides=4, padding="same", activation="relu")(inp)
    x = layers.MaxPooling1D(4)(x)
    x = layers.BatchNormalization()(x)
    
    x = layers.Conv1D(32, 8, strides=4, padding="same", activation="relu")(x)
    x = layers.MaxPooling1D(4)(x)
    x = layers.BatchNormalization()(x)

    x = layers.Conv1D(64, 4, strides=2, padding="same", activation="relu")(x)
    x = layers.MaxPooling1D(2)(x)
    x = layers.BatchNormalization()(x)

    x = layers.Conv1D(128, 4, strides=2, padding="same", activation="relu")(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dropout(0.5)(x)

    x = layers.Dense(64, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(1, activation="sigmoid", name="scream_probability")(x)

    model = models.Model(inp, out, name="RawAudioScreamDetector")
    return model

def train(X_train, y_train, X_val, y_val):

    print("\n" + "=" * 60)
    print("STEP 4: Training 1D CNN model…")
    print("=" * 60)

    classes = np.unique(y_train)
    weights = compute_class_weight("balanced", classes=classes, y=y_train)
    class_weight = {int(c): float(w) for c, w in zip(classes, weights)}

    model = build_model()
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=CFG["learning_rate"]),
        loss="binary_crossentropy",
        metrics=["accuracy", tf.keras.metrics.AUC(name="auc")],
    )

    checkpoint_path = os.path.join(CFG["output_dir"], "best_model.keras")
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(checkpoint_path, save_best_only=True, monitor="val_auc", mode="max"),
        tf.keras.callbacks.EarlyStopping(monitor="val_auc", patience=CFG["early_stopping_patience"], mode="max", restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=3, min_lr=1e-6),
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=CFG["epochs"],
        batch_size=CFG["batch_size"],
        class_weight=class_weight,
        callbacks=callbacks,
        verbose=1,
    )
    return model, history


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 & 6 — EVALUATION AND EXPORT
# ─────────────────────────────────────────────────────────────────────────────
def evaluate_and_export(model, X_test, y_test):
    print("\n" + "=" * 60)
    print("STEP 5 & 6: Evaluation & TFLite Export")
    print("=" * 60)

    y_pred_prob = model.predict(X_test, verbose=0).flatten()
    y_pred = (y_pred_prob >= 0.5).astype(int)
    auc = roc_auc_score(y_test, y_pred_prob)
    print(f"\n  Test ROC-AUC Score: {auc:.4f}")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(CFG["tflite_output"], "wb") as f:
        f.write(tflite_model)

    print(f"\n  ✅ RAW AUDIO TFLite model saved: {CFG['tflite_output']}")
    print(f"  Input shape required by Flutter: [1, 66150, 1]")
    print(f"  (Just feed the raw PCM float array!)")

def main():
    df = scan_dataset()
    cache_path = os.path.join(CFG["output_dir"], "raw_features_cache.npz")
    X, y = build_feature_arrays(df, cache_path)
    X_train, X_val, X_test, y_train, y_val, y_test = split_data(X, y)
    model, history = train(X_train, y_train, X_val, y_val)
    evaluate_and_export(model, X_test, y_test)

if __name__ == "__main__":
    main()
