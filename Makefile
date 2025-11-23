NVCC = nvcc
# Added -arch=sm_75 to match Colab's Tesla T4 GPU and fix toolchain error
NVCC_FLAGS = -arch=sm_75 

TARGET = image_proc
SRC = src/main.cu

all: $(TARGET)

$(TARGET): $(SRC)
	$(NVCC) $(NVCC_FLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)
