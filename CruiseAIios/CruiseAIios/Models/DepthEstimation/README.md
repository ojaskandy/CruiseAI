# Depth Estimation Model

Place your depth estimation model files in this directory.

## Expected Files

- Model file (e.g., `.mlmodel`, `.tflite`, or custom format)
- Any supporting files or assets required by the model
- Configuration files if needed

## Integration

The model placed here will be used for estimating depth from the camera feed, such as:
- Distance to objects
- 3D scene reconstruction
- Spatial mapping
- Obstacle avoidance calculations

## Notes

- Ensure your model is compatible with iOS
- If using Core ML, include the `.mlmodel` file
- If using TensorFlow Lite, include the `.tflite` file
- For custom implementations, include all necessary files
