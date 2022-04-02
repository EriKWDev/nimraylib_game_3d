#version 330

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables
#define MAX_LIGHTS 30

const int DIRECTIONAL = 0;
const int POINT = 1;
const int SPOT = 2;

struct Light {
  int kind;
  int enabled;
  vec3 color;
  
  vec3 position;
  vec3 target;
};

struct LightCalcResult {
  vec4 diffuse;
  vec4 specular;
  vec3 nDotL;
};

uniform Light lights[MAX_LIGHTS];
uniform vec4 ambient;
uniform vec3 viewPos;

vec3 get_light_calc(Light light) {
  vec3 result = vec3(0.0, 0.0, 0.0);
  
  return result;
}

const float radius = 20.2;
const float dr = radius * radius;

void main() {
  vec3 normal = normalize(fragNormal);
  vec3 viewD = normalize(viewPos - fragPosition);
  
  vec4 texelColor = texture(texture0, fragTexCoord);
  
  vec3 lightDot = vec3(0.0);
  vec3 specular = vec3(0.0);
  
  for(int i = 0; i < MAX_LIGHTS; i ++ ) {
    Light light = lights[i];
    
    if (light.enabled == 1) {
      vec3 lightValue = vec3(0.0);
      float mul = 1.0;
      
      if (light.kind == DIRECTIONAL) {
        vec3 dir = -normalize(light.target - light.position);
        
        lightValue = dir;
      }
      
      if (light.kind == POINT) {
        vec3 dir = light.position - fragPosition;
        
        lightValue = normalize(dir);
        
        float dist = length(dir);
        
        mul = clamp(1.0 - dist * dist / (dr), 0.0, 1.0);
        mul *= mul;
      }
      
      float NdotL = max(dot(normal, lightValue), 0.0);
      lightDot += light.color.rgb * NdotL * mul;
      
      float specCo = 0.0;
      if (NdotL > 0.0) {
        specCo = pow(max(0.0, dot(viewD, reflect(-(lightValue), normal))), 8.0); // 16 refers to shine
      }
      
      specular += specCo;
    }
  }
  
  finalColor = (texelColor * ((colDiffuse + vec4(specular, 1.0)) * vec4(lightDot, 1.0)));
  finalColor += texelColor * (ambient / 10.0) * colDiffuse;
  
  // Gamma correction
  float gamma = 2.4;
  finalColor = pow(finalColor, vec4(1.0 / gamma));
}