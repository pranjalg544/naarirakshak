"""
=============================================================================
NaariRakshak — Scream Detection Model Training Pipeline
=============================================================================
Pipeline:
  1. Scan dataset folders → build file manifest with labels
  2. Preprocess: resample → mono → 3-second chunks
  3. Feature Extraction: 128-band Mel Spectrogram (128×128 image)
  4. Train / Val / Test Split: 70 / 15 / 15
  5. Train CNN model with class-weight balancing
  6. Evaluate: confusion matrix, classification report, ROC-AUC
  7. Export to TFLite → assets/scream_detector.tflite

Requirements (install before running):
  pip install tensorflow librosa numpy pandas scikit-learn matplotlib seaborn tqdm soundfile

Run:
  python ml/train_scream_detector.py
=============================================================================
"""

import os
import sys
import json
import warnings
import numpy as np
import pandas as pd
import librosa
import soundfile as sf
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
    # Audio
    "sample_rate": 22050,          # Hz — standard for audio ML
    "clip_duration": 3.0,          # seconds per chunk
    "n_mels": 128,                 # Mel filter banks
    "n_fft": 2048,                 # FFT window size
    "hop_length": 512,             # frames between FFT windows
    "fmax": 8000,                  # max frequency (Hz) — scream range

    # Model
    "img_height": 128,             # spectrogram height (n_mels)
    "img_width": 128,              # spectrogram width (time frames)
    "batch_size": 32,
    "epochs": 40,
    "learning_rate": 1e-3,
    "early_stopping_patience": 8,

    # Paths (relative to project root)
    "dataset_root": r"D:\naarirakshak\dataset",
    "output_dir": r"D:\naarirakshak\ml\output",
    "tflite_output": r"D:\naarirakshak\assets\scream_detector.tflite",
}

# ─────────────────────────────────────────────────────────────────────────────
# DATASET FOLDERS  →  label mapping
# ─────────────────────────────────────────────────────────────────────────────
LABEL_MAP = {
    # label 1 = SCREAM
    r"archive\Screaming":                          1,
    r"archive (1)\Converted_Separately\scream":    1,
    r"archive (2)":                                1,  # Added this as per our discovery
    # label 0 = NOT SCREAM
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
            print(f"  ⚠  Folder not found: {folder}")
            continue

        files = [f for f in folder.rglob("*") if f.suffix.lower() in AUDIO_EXTENSIONS]
        print(f"  {'SCREAM' if label == 1 else 'NON-SCREAM':12} | {len(files):5,} files | {rel_folder}")

        for f in files:
            records.append({"filepath": str(f), "label": label,
                            "label_name": "scream" if label == 1 else "not_scream"})

    df = pd.DataFrame(records).drop_duplicates(subset="filepath")
    print(f"\n  Total files found: {len(df):,}")
    print(f"  Scream:     {df['label'].sum():,}")
    print(f"  Non-Scream: {(df['label'] == 0).sum():,}")
    print(f"  Class ratio: 1:{(df['label'] == 0).sum() // max(df['label'].sum(), 1)}")

    df.to_csv(os.path.join(CFG["output_dir"], "manifest.csv"), index=False)
    return df


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 + 3 — PREPROCESS + FEATURE EXTRACTION
# ─────────────────────────────────────────────────────────────────────────────
def audio_to_melspec(filepath: str) -> list[np.ndarray]:
    """
    Load audio file → resample → mono → split into 3s chunks →
    compute 128-band Mel Spectrogram for each chunk.
    Returns a list of (128 x 128) float32 arrays (log-scaled dB).
    """
    clip_len = int(CFG["sample_rate"] * CFG["clip_duration"])
    target_frames = CFG["img_width"]  # 128 time frames per spectrogram

    try:
        y, sr = librosa.load(filepath, sr=CFG["sample_rate"], mono=True)
    except Exception as e:
        return []  # skip unreadable files

    # Normalise amplitude
    y = librosa.util.normalize(y)

    # Chunk into 3-second clips (with overlap of 1.5s for data augmentation)
    chunks = []
    step = clip_len // 2  # 50% overlap
    if len(y) < clip_len:
        # Pad short files
        y = np.pad(y, (0, clip_len - len(y)))
        chunks = [y]
    else:
        for start in range(0, len(y) - clip_len + 1, step):
            chunks.append(y[start: start + clip_len])

    specs = []
    for chunk in chunks:
        mel = librosa.feature.melspectrogram(
            y=chunk,
            sr=CFG["sample_rate"],
            n_mels=CFG["n_mels"],
            n_fft=CFG["n_fft"],
            hop_length=CFG["hop_length"],
            fmax=CFG["fmax"],
        )
        mel_db = librosa.power_to_db(mel, ref=np.max)

        # Resize to exactly (128 x 128)
        if mel_db.shape[1] != target_frames:
            import cv2
            mel_db = cv2.resize(mel_db, (target_frames, CFG["img_height"]))

        # Normalise to [0, 1]
        mel_db = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min() + 1e-8)
        specs.append(mel_db.astype(np.float32))

    return specs


def build_feature_arrays(df: pd.DataFrame, cache_path: str) -> tuple[np.ndarray, np.ndarray]:
    """
    Build (X, y) feature arrays from a file manifest.
    Caches to disk as .npz to avoid recomputing on reruns.
    """
    if os.path.exists(cache_path):
        print(f"\n  ✅ Loading cached features from {cache_path}")
        data = np.load(cache_path)
        return data["X"], data["y"]

    print("\n" + "=" * 60)
    print("STEP 2+3: Preprocessing audio & extracting Mel Spectrograms…")
    print(f"  This may take several minutes depending on dataset size.")
    print("=" * 60)

    X_list, y_list = [], []
    errors = 0

    for _, row in tqdm(df.iterrows(), total=len(df), desc="Processing"):
        specs = audio_to_melspec(row["filepath"])
        if not specs:
            errors += 1
            continue
        for spec in specs:
            X_list.append(spec)
            y_list.append(row["label"])

    print(f"\n  Files skipped (errors): {errors}")
    print(f"  Total samples generated: {len(X_list):,}")

    X = np.array(X_list)[..., np.newaxis]  # → (N, 128, 128, 1)
    y = np.array(y_list)

    np.savez_compressed(cache_path, X=X, y=y)
    print(f"  ✅ Features cached to {cache_path}")
    return X, y


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — TRAIN / VAL / TEST SPLIT
# ─────────────────────────────────────────────────────────────────────────────
def split_data(X: np.ndarray, y: np.ndarray):
    print("\n" + "=" * 60)
    print("STEP 4: Train / Val / Test Split (70 / 15 / 15)")
    print("=" * 60)

    # Stratified split to preserve class ratio
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=0.30, random_state=42, stratify=y
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.50, random_state=42, stratify=y_temp
    )

    for name, arr, labels in [
        ("Train", X_train, y_train),
        ("Val",   X_val,   y_val),
        ("Test",  X_test,  y_test),
    ]:
        print(f"  {name:6}: {len(arr):6,} samples  |  "
              f"Scream: {labels.sum():,}  Non-Scream: {(labels == 0).sum():,}")

    return X_train, X_val, X_test, y_train, y_val, y_test


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — MODEL DEFINITION
# ─────────────────────────────────────────────────────────────────────────────
def build_model() -> tf.keras.Model:
    layers = tf.keras.layers
    models = tf.keras.models
    regularizers = tf.keras.regularizers

    inp = layers.Input(shape=(CFG["img_height"], CFG["img_width"], 1), name="mel_input")

    # Block 1
    x = layers.Conv2D(32, (3, 3), padding="same", activation="relu")(inp)
    x = layers.BatchNormalization()(x)
    x = layers.Conv2D(32, (3, 3), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D((2, 2))(x)
    x = layers.Dropout(0.25)(x)

    # Block 2
    x = layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Conv2D(64, (3, 3), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D((2, 2))(x)
    x = layers.Dropout(0.25)(x)

    # Block 3
    x = layers.Conv2D(128, (3, 3), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Conv2D(128, (3, 3), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.40)(x)

    # Classifier head
    x = layers.Dense(256, activation="relu",
                     kernel_regularizer=regularizers.l2(1e-4))(x)
    x = layers.Dropout(0.40)(x)
    out = layers.Dense(1, activation="sigmoid", name="scream_probability")(x)

    model = models.Model(inp, out, name="ScreamDetector")
    return model


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — TRAINING
# ─────────────────────────────────────────────────────────────────────────────
def train(X_train, y_train, X_val, y_val):

    print("\n" + "=" * 60)
    print("STEP 5: Training CNN model…")
    print("=" * 60)

    # Compute class weights to handle imbalance
    classes = np.unique(y_train)
    weights = compute_class_weight("balanced", classes=classes, y=y_train)
    class_weight = {int(c): float(w) for c, w in zip(classes, weights)}
    print(f"  Class weights: {class_weight}")

    model = build_model()
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=CFG["learning_rate"]),
        loss="binary_crossentropy",
        metrics=["accuracy",
                 tf.keras.metrics.AUC(name="auc"),
                 tf.keras.metrics.Precision(name="precision"),
                 tf.keras.metrics.Recall(name="recall")],
    )

    # Callbacks
    checkpoint_path = os.path.join(CFG["output_dir"], "best_model.keras")
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            checkpoint_path, save_best_only=True, monitor="val_auc", mode="max",
            verbose=1
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_auc", patience=CFG["early_stopping_patience"],
            mode="max", restore_best_weights=True, verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6, verbose=1
        ),
        tf.keras.callbacks.CSVLogger(
            os.path.join(CFG["output_dir"], "training_log.csv")
        ),
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
# STEP 6 — EVALUATION
# ─────────────────────────────────────────────────────────────────────────────
def evaluate(model, X_test, y_test, history):
    print("\n" + "=" * 60)
    print("STEP 6: Evaluation on Test Set")
    print("=" * 60)

    y_pred_prob = model.predict(X_test, verbose=0).flatten()
    y_pred = (y_pred_prob >= 0.5).astype(int)

    # Classification report
    print("\n  Classification Report:")
    print(classification_report(y_test, y_pred, target_names=["not_scream", "scream"]))

    # ROC-AUC
    auc = roc_auc_score(y_test, y_pred_prob)
    print(f"  ROC-AUC Score: {auc:.4f}")

    # --- Confusion Matrix Plot ---
    cm = confusion_matrix(y_test, y_pred)
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))

    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", ax=axes[0],
                xticklabels=["Not Scream", "Scream"],
                yticklabels=["Not Scream", "Scream"])
    axes[0].set_title("Confusion Matrix")
    axes[0].set_ylabel("True Label")
    axes[0].set_xlabel("Predicted Label")

    # --- Training History Plot ---
    axes[1].plot(history.history["accuracy"],  label="Train Acc")
    axes[1].plot(history.history["val_accuracy"], label="Val Acc")
    axes[1].plot(history.history["auc"],       label="Train AUC", linestyle="--")
    axes[1].plot(history.history["val_auc"],   label="Val AUC",   linestyle="--")
    axes[1].set_title("Accuracy & AUC")
    axes[1].set_xlabel("Epoch")
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    # --- ROC Curve ---
    fpr, tpr, _ = roc_curve(y_test, y_pred_prob)
    axes[2].plot(fpr, tpr, label=f"AUC = {auc:.4f}", color="crimson")
    axes[2].plot([0, 1], [0, 1], "k--", alpha=0.5)
    axes[2].set_title("ROC Curve")
    axes[2].set_xlabel("False Positive Rate")
    axes[2].set_ylabel("True Positive Rate")
    axes[2].legend()
    axes[2].grid(True, alpha=0.3)

    plt.suptitle("NaariRakshak — Scream Detector Evaluation", fontsize=14, fontweight="bold")
    plt.tight_layout()
    plot_path = os.path.join(CFG["output_dir"], "evaluation_plots.png")
    plt.savefig(plot_path, dpi=150, bbox_inches="tight")
    try:
        plt.show()
    except Exception:
        pass  # Running headless
    print(f"\n  ✅ Evaluation plots saved to: {plot_path}")

    # Save metrics to JSON
    metrics = {
        "roc_auc": float(auc),
        "classification_report": classification_report(y_test, y_pred,
            target_names=["not_scream", "scream"], output_dict=True)
    }
    with open(os.path.join(CFG["output_dir"], "metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    return auc


# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — TFLITE EXPORT
# ─────────────────────────────────────────────────────────────────────────────
def export_tflite(model):

    print("\n" + "=" * 60)
    print("STEP 7: Exporting to TFLite…")
    print("=" * 60)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]           # float16 quantisation
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    # Save to Flutter assets
    tflite_path = CFG["tflite_output"]
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    size_kb = os.path.getsize(tflite_path) / 1024
    print(f"  ✅ TFLite model saved: {tflite_path}")
    print(f"  📦 Model size: {size_kb:.1f} KB ({size_kb / 1024:.2f} MB)")
    print()
    print("  Flutter integration steps:")
    print("  1. Add to pubspec.yaml assets:")
    print("       - assets/scream_detector.tflite")
    print("  2. Add dependency: tflite_flutter: ^0.10.0")
    print("  3. Use lib/services/audio_detection_service.dart to load & infer")
    print()

    return tflite_path


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  NaariRakshak — Scream Detector Training Pipeline")
    print("=" * 60)

    # Check TensorFlow
    try:
        print(f"\n  TensorFlow version: {tf.__version__}")
        gpus = tf.config.list_physical_devices("GPU")
        print(f"  GPU devices: {gpus if gpus else 'None (CPU mode)'}")
    except ImportError:
        print("  ❌ TensorFlow not found. Install: pip install tensorflow")
        sys.exit(1)

    # Check librosa
    try:
        import librosa
        print(f"  Librosa version: {librosa.__version__}")
    except ImportError:
        print("  ❌ Librosa not found. Install: pip install librosa")
        sys.exit(1)

    import cv2 # Check for cv2 as we use it

    # Step 1 — Scan dataset
    df = scan_dataset()
    if len(df) == 0:
        print("  ❌ No audio files found. Check dataset paths in CFG.")
        sys.exit(1)

    # Step 2+3 — Feature extraction (cached)
    cache_path = os.path.join(CFG["output_dir"], "features_cache.npz")
    X, y = build_feature_arrays(df, cache_path)

    print(f"\n  Feature array shape: X={X.shape}, y={y.shape}")
    print(f"  Scream samples:     {y.sum():,}")
    print(f"  Non-Scream samples: {(y == 0).sum():,}")

    # Step 4 — Split
    X_train, X_val, X_test, y_train, y_val, y_test = split_data(X, y)

    # Step 5 — Train
    model, history = train(X_train, y_train, X_val, y_val)

    # Step 6 — Evaluate
    auc = evaluate(model, X_test, y_test, history)

    # Step 7 — Export
    if auc >= 0.80:
        export_tflite(model)
    else:
        print(f"\n  ⚠ AUC = {auc:.4f} is below 0.80 threshold.")
        print("  Consider more data, augmentation, or longer training.")
        print("  Exporting anyway for inspection…")
        export_tflite(model)

    print("\n" + "=" * 60)
    print("  ✅ Pipeline complete!")
    print(f"  Output directory: {CFG['output_dir']}")
    print("=" * 60)


if __name__ == "__main__":
    main()
