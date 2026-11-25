"""Generate missing model/audio/image C arrays from repository assets."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]/'drivers/tflm/my_tflm/tflite-micro'
generator = 'tensorflow/lite/micro/tools/generate_cc_arrays.py'
assets = [
    'tensorflow/lite/micro/examples/hello_world/models/hello_world_int8.tflite',
    'tensorflow/lite/micro/models/person_detect.tflite',
    'tensorflow/lite/micro/examples/person_detection/testdata/person.bmp',
    'tensorflow/lite/micro/examples/person_detection/testdata/no_person.bmp',
    'tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized.tflite',
    'tensorflow/lite/micro/examples/micro_speech/models/audio_preprocessor_int8.tflite',
    'tensorflow/lite/micro/examples/micro_speech/testdata/yes_1000ms.wav',
    'tensorflow/lite/micro/examples/micro_speech/testdata/no_1000ms.wav',
]
subprocess.run([sys.executable,generator,'gen/linux_x86_64_default/genfiles',*assets],cwd=root,check=True)
subprocess.run([sys.executable,generator,'gen','my_model/models/justure_detect.tflite',
                'my_model/testdata/Z_test.bmp','my_model/testdata/W_test.bmp'],cwd=root,check=True)
