# NaariRakshak - Scream Detection Model Summary

## 1. Overview
This model is a custom Convolutional Neural Network (CNN) designed to detect human screams from raw audio in real-time. It processes audio chunks by converting them into 128-band Mel Spectrograms (visual representations of audio frequencies), which are then analyzed by the CNN to output a probability of a scream.

## 2. Dataset & Preprocessing
- **Sample Rate**: 22050 Hz (Mono)
- **Chunk Size**: 3 seconds per sample (with 50% overlap for augmentation)
- **Features**: 128x128 Mel Spectrograms
- **Total Samples Generated**: 21,958
  - **Non-Scream**: 14,759
  - **Scream**: 7,199
- **Data Split**: Stratified split of 70% Train / 15% Validation / 15% Test.

## 3. Training Details
- **Architecture**: 3-block CNN with Batch Normalization, MaxPooling, and Dropout, ending with a Dense classification head.
- **Handling Imbalance**: Computed and applied class weights so the model pays equal attention to screams despite them being less frequent in the dataset.
- **Optimization**: Adam optimizer with Early Stopping (monitoring Validation AUC) and learning rate reduction on plateaus.

## 4. Evaluation & Performance (Test Set)
The model was evaluated on the 15% hold-out test set (completely unseen data). It achieved outstanding results:
- **Overall Accuracy**: ~91%
- **ROC-AUC Score**: **0.9678** (Excellent ability to distinguish between scream and non-scream)

**Classification Report Summary**:
- **Scream Detection Precision**: 85% (When it predicts a scream, it's correct 85% of the time)
- **Scream Detection Recall**: 89% (It successfully catches 89% of all actual screams)
- **Scream F1-Score**: 87%

## 5. Deployment
- **Format**: TensorFlow Lite (`.tflite`) with Float16 Quantization.
- **Final Model Size**: ~639.4 KB (0.62 MB)
- **Location**: `D:\naarirakshak\assets\scream_detector.tflite`

The model is highly optimized, lightweight, and ready for on-device edge inference within the Flutter mobile application.
