#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <sstream>
#include <dirent.h>
#include <cuda_runtime.h>

// Error checking macro
#define cudaCheckError(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true) {
   if (code != cudaSuccess) {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

// Kernel: Converts RGB to Grayscale
// Uses the formula: Y = 0.299*R + 0.587*G + 0.114*B
__global__ void grayscaleKernel(int* d_in, int* d_out, int num_pixels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < num_pixels) {
        int r = d_in[idx * 3];
        int g = d_in[idx * 3 + 1];
        int b = d_in[idx * 3 + 2];

        int gray = (int)(0.299f * r + 0.587f * g + 0.114f * b);

        // Write same value to R, G, and B to create grayscale
        d_out[idx * 3] = gray;
        d_out[idx * 3 + 1] = gray;
        d_out[idx * 3 + 2] = gray;
    }
}

// Helper to process a single file
void processImage(std::string inputPath, std::string outputPath) {
    std::ifstream inFile(inputPath);
    if (!inFile.is_open()) {
        std::cerr << "Error opening input: " << inputPath << std::endl;
        return;
    }

    std::string format;
    int width, height, maxVal;
    inFile >> format >> width >> height >> maxVal;

    int numPixels = width * height;
    int numValues = numPixels * 3;
    size_t bytes = numValues * sizeof(int);

    // Host memory
    std::vector<int> h_in(numValues);
    std::vector<int> h_out(numValues);

    for (int i = 0; i < numValues; ++i) {
        inFile >> h_in[i];
    }
    inFile.close();

    // Device memory
    int *d_in, *d_out;
    cudaCheckError(cudaMalloc(&d_in, bytes));
    cudaCheckError(cudaMalloc(&d_out, bytes));

    // Copy to device
    cudaCheckError(cudaMemcpy(d_in, h_in.data(), bytes, cudaMemcpyHostToDevice));

    // Launch Kernel
    int blockSize = 256;
    int gridSize = (numPixels + blockSize - 1) / blockSize;
    grayscaleKernel<<<gridSize, blockSize>>>(d_in, d_out, numPixels);
    cudaCheckError(cudaGetLastError());
    cudaCheckError(cudaDeviceSynchronize());

    // Copy back
    cudaCheckError(cudaMemcpy(h_out.data(), d_out, bytes, cudaMemcpyDeviceToHost));

    // Write output
    std::ofstream outFile(outputPath);
    outFile << "P3\n" << width << " " << height << "\n" << maxVal << "\n";
    for (int i = 0; i < numValues; i += 3) {
        outFile << h_out[i] << " " << h_out[i+1] << " " << h_out[i+2] << "\n";
    }
    outFile.close();

    // Cleanup
    cudaFree(d_in);
    cudaFree(d_out);
}

int main(int argc, char** argv) {
    std::string inputDir = "";
    std::string outputDir = "";

    // CLI Argument Parsing (Simple)
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-i" && i + 1 < argc) inputDir = argv[++i];
        else if (arg == "-o" && i + 1 < argc) outputDir = argv[++i];
    }

    if (inputDir.empty() || outputDir.empty()) {
        std::cout << "Usage: ./image_proc -i <input_dir> -o <output_dir>\n";
        return 1;
    }

    std::cout << "Processing images from " << inputDir << " to " << outputDir << "...\n";

    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir(inputDir.c_str())) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            std::string fname = ent->d_name;
            if (fname.length() > 4 && fname.substr(fname.length() - 4) == ".ppm") {
                std::string inPath = inputDir + "/" + fname;
                std::string outPath = outputDir + "/" + fname;
                processImage(inPath, outPath);
            }
        }
        closedir(dir);
    } else {
        std::cerr << "Could not open directory" << std::endl;
        return 1;
    }

    std::cout << "Processing complete." << std::endl;
    return 0;
}
