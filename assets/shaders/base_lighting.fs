#version 100

precision mediump float;

// Input vertex attributes (from vertex shader)
varying vec3 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;
varying vec3 fragNormal;
varying vec4 fragPositionLightSpace;

// Input uniform values
uniform vec4 colDiffuse;
uniform sampler2D texture0;
uniform sampler2D lightDepth;
uniform vec3 viewPos;

#define MAX_LIGHTS 40
#define MAX_DIRECTIONAL_LIGHTS 1

struct Light{
  vec3 position;
  vec3 color;
};

uniform Light lights[MAX_LIGHTS];

struct DirectionalLight{
  vec3 color;
  vec3 direction;
};

uniform DirectionalLight directionalLights[MAX_DIRECTIONAL_LIGHTS];

float shadow_calculation(vec4 fragPosLightSpace)
{
  // perform perspective divide
  vec3 projCoords=fragPosLightSpace.xyz/fragPosLightSpace.w;
  // transform to [0,1] range
  projCoords=projCoords*.5+.5;
  // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
  float closestDepth=texture2D(lightDepth,projCoords.xy).r;
  // get depth of current fragment from light's perspective
  float currentDepth=projCoords.z;
  // check whether current frag pos is in shadow
  float shadow=currentDepth>closestDepth?.9:0.;
  
  return 1.-shadow;
}

void main(){
  vec3 normal=normalize(fragNormal);
  vec3 viewDirection=normalize(viewPos-fragPosition);
  
  vec4 diffuse=vec4(0.);
  
  float specularStrength=.8;
  vec3 specular=vec3(0.);
  
  float shadow=shadow_calculation(fragPositionLightSpace);
  
  for(int i=0;i<MAX_DIRECTIONAL_LIGHTS;i++){
    vec3 light=normalize(directionalLights[i].direction);
    
    float NdotL=max(dot(normal,light),0.);
    diffuse+=NdotL*vec4(directionalLights[i].color.rgb,1.)*shadow;
    
    float specCo=0.;
    if(NdotL>0.){
      specCo=pow(max(0.,dot(viewDirection,reflect(-(light),normal))),16.);// 16 refers to shine
      specular+=specCo*shadow;
    }
  }
  
  for(int i=0;i<MAX_LIGHTS;i++){
    vec3 dir=lights[i].position-fragPosition;
    vec3 light=normalize(dir);
    float dist=length(dir);
    
    float d=(1.+1.5*dist+1.3*dist*dist);
    float attenuation=clamp(10./d,0.,1.);
    
    float NdotL=max(dot(normal,light),0.);
    diffuse+=vec4(lights[i].color.rgb,1.)*attenuation*NdotL;
    
    float specCo=0.;
    if(NdotL>0.){
      specCo=pow(max(0.,dot(viewDirection,reflect(-(light),normal))),16.);// 16 refers to shine
      specular+=specCo*attenuation;//*lights[i].color;
    }
  }
  
  vec4 texelColor=texture2D(texture0,fragTexCoord)*colDiffuse;
  
  //combine
  vec4 theLight=texelColor+vec4(specular,1.)*diffuse;
  theLight.w=1.;
  
  vec4 finalColor=theLight;
  finalColor.w=1.;
  finalColor+=diffuse*.03;
  
  gl_FragColor=finalColor;
}