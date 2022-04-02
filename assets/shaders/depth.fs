#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0; // Depth texture
uniform vec4 colDiffuse;
uniform sampler2D shadowMap;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

const float zNear = 0.01; // camera z near
const float zFar = 200.0; // camera z far

float linearize_depth(float d) {
  return zNear * zFar / (zFar + d * (zNear - zFar));
}

void main() {
  float z = texture(shadowMap, fragTexCoord).r;
  finalColor = vec4(vec3(z), 1.0);
  
  // Linearize depth value
  // float depth = linearize_depth(z);
  
  // Calculate final fragment color
  // finalColor = vec4(vec3(depth), 1.0);
}