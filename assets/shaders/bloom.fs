#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 bufferSize;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

// const vec2 size=vec2(800,450);// Framebuffer size
const float samples=8.;// Pixels per axis; higher = bigger glow, worse performance

const float gamma=.5;
const float exposure=1.2;
const float quality=1.2;

vec4 gammaCorrect(vec4 source){
  return pow(source,vec4(4));
}

vec4 lerp(vec4 from,vec4 to,float t){
  return(1.-t)*from+t*to;
}

void main()
{
  // Texel color fetching from texture sampler
  vec4 source=texture(texture0,fragTexCoord);
  
  vec4 sum=vec4(0);
  vec2 sizeFactor=vec2(1)/bufferSize*quality;
  const int range=3;// should be = (samples - 1)/2;
  vec4 bloomColor=vec4(0.);
  
  for(int x=-range;x<=range;x++)
  {
    for(int y=-range;y<=range;y++)
    {
      vec4 sample=gammaCorrect(texture(texture0,fragTexCoord+vec2(x,y)*sizeFactor));
      sum+=sample;
    }
  }
  
  // Calculate final fragment color
  bloomColor=((sum/(samples*samples))+source)*colDiffuse;
  
  //vec4 mapped=1.-exp(-bloomColor*exposure);
  //mapped=pow(mapped,vec4(1./gamma));
  
  //finalColor=mapped;
  // finalColor=lerp(source,mapped,t);
  finalColor=bloomColor;
}
