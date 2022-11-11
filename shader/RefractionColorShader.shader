Shader "CrystalSymulator/RefractionColorShader"
{
    Properties
    {
        _MainTex("Refraction Color", 2D) = "white" {}
        _OpenNicolTex("Open Nicol Color", 2D) = "white" {}
        _AxisMap("Optical Axis Map", 2D) = "white" {}
        _RefractionIndexX ("RefractionX", Range(0.01, 10)) = 1.0
        _RefractionIndexY ("RefractionY", Range(0.01, 10)) = 1.0
        _RefractionIndexZ ("RefractionZ", Range(0.01, 10)) = 1.0
        _Thickness ("Thickness(um)", Range(0, 100)) = 30 
        _Rotation ("Rotation", range(0.0, 360.0)) = 0
        [MaterialToggle] _CrossNicol ("IsCrossNicol", Float) = 0

        _OpticalAxis ("Optical Axis", Vector) = (0, 1, 1, 0)
    }

    SubShader
    {
        Tags
        { 
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        PASS 
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _OpenNicolTex;
            sampler2D _AxisMap;
            float _RefractionIndexX;
            float _RefractionIndexY;
            float _RefractionIndexZ;
            float _Thickness;
            float _Rotation;
            float _CrossNicol;

            float4 _OpticalAxis;

            float4 MulQuaternion(float4 q, float4 p)
            {
                float4x4 A = float4x4(
                     q.w, -q.z,  q.y, q.x,
                     q.z,  q.w, -q.x, q.y,
                    -q.y,  q.x,  q.w, q.z,
                    -q.x, -q.y, -q.z, q.w
                );

                return normalize(mul(A, p));
            }

            float4 Quaternion(float3 vec, float theta)
            {
                return float4(
                    vec * sin(theta / 2),
                    cos(theta / 2)
                );
            }
            
            float4 RotateVector(float4 q, float4 vec)
            {
                float4 co_q = float4(-q.xyz, q.w);
                return MulQuaternion(MulQuaternion(q, vec), co_q);
            }

            float CalcV() 
            {
                float a = _RefractionIndexX;
                float b = _RefractionIndexY;
                float c = _RefractionIndexZ;
                return acos(
                    a / b * sqrt((c * c - b * b) /(c * c - a * a))
                );
            }

            float CalcAngle(float3 vec1, float3 vec2)
            { 
                if (length(vec1) < 0.001 || length(vec2) < 0.001) {
                    return 0;
                }

                return acos(abs(dot(normalize(vec1), normalize(vec2))));
            }

            float2 CalcRefraction(float phi1, float phi2)
            {
                float a = _RefractionIndexX;
                float c = _RefractionIndexZ;
                
                float refraction1 = sqrt(
                    2 * c * c * a * a / 
                    ((c * c + a * a) + (c * c - a * a) * cos(phi1 - phi2))
                );
                
                float refraction2 = sqrt(
                    2 * c * c * a * a / 
                    ((c * c + a * a) + (c * c - a * a) * cos(phi1 + phi2))
                );


                return float2(min(refraction1, refraction2), max(refraction1, refraction2));
            }

            float2 CalcRefractions(float4 initial_quaternion, float3 light_dir)
            {
                float4 x = RotateVector(initial_quaternion, float4(1, 0, 0, 0));
                float4 y = RotateVector(initial_quaternion, float4(0, 1, 0, 0));
                float4 z = RotateVector(initial_quaternion, float4(0, 0, 1, 0));
                
                float V = CalcV(); 
                float4 optical_axis1 = RotateVector(Quaternion(y.xyz,  V), z);
                float4 optical_axis2 = RotateVector(Quaternion(y.xyz, -V), z);

                float phi1 = CalcAngle(light_dir, optical_axis1.xyz);
                float phi2 = CalcAngle(light_dir, optical_axis2.xyz);

                return CalcRefraction(phi1, phi2);
            }

            float EdgeValue(float2 position, float3 light_dir) 
            {
                // TODO: 屈折率の差によるオープンニコルの境界描画を行う
                return 1;
            }

            // ZXYの順番で回転させる
            // https://qiita.com/metaaa/items/a38112efb4499cb7e908#%E3%82%AA%E3%82%A4%E3%83%A9%E3%83%BC%E8%A7%92%E3%81%8B%E3%82%89%E3%82%AF%E3%82%A9%E3%83%BC%E3%82%BF%E3%83%8B%E3%82%AA%E3%83%B3%E3%81%B8%E3%81%AE%E5%A4%89%E6%8F%9B
            float4 InitialQuaternion(float3 rgb)
            {
                float PI = 3.14159265359;
                rgb = rgb * PI * 0.5;
                return float4(cos(rgb.x)*cos(rgb.y)*cos(rgb.z) + sin(rgb.x)*sin(rgb.y)*sin(rgb.z),
                              sin(rgb.x)*cos(rgb.y)*cos(rgb.z) + cos(rgb.x)*sin(rgb.y)*sin(rgb.z),
                              cos(rgb.x)*sin(rgb.y)*cos(rgb.z) - sin(rgb.x)*cos(rgb.y)*sin(rgb.z),
                              cos(rgb.x)*cos(rgb.y)*sin(rgb.z) - sin(rgb.x)*sin(rgb.y)*cos(rgb.z)); 
            }

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f 
            {
                float4 vertex : SV_POSITION;
                float2 position : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o = (v2f) 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.position = v.uv;
                o.position.x = 1.0 - o.position.x;
                #if UNITY_UV_STARTS_AT_TOP
                    o.position.y = 1.0 - o.position.y;
                #endif
                return o;
            }

            fixed4 frag(v2f i) : SV_TARGET
            {
                float PI = 3.14159265359;
                float3 light_dir = float3(0, 1, 0);
                
                float4 initial_quaternion = InitialQuaternion(tex2D(_AxisMap, i.position).xyz);
                float2 refraction = CalcRefractions(initial_quaternion, light_dir);

                float diff_refraction = abs(refraction.x - refraction.y);
                float standard_thickness = 30.0;
                float birefresence = diff_refraction * _Thickness / standard_thickness;
                
                float4 x = RotateVector(initial_quaternion, float4(1, 0, 0, 0));
                float4 z = RotateVector(initial_quaternion, float4(0, 0, 1, 0));
                // 本当は光ではなく物体を回転させるので、負の方向の回転になる
                if (x.x - x.z - z.x + z.z < 0.0001) {
                    x = -x;
                }  
                float t = (z.z - z.x) / (x.x - x.z - z.x + z.z);
                float4 light_wave_dir = t * x + (1 - t) * z;
                float theta = CalcAngle(light_wave_dir.xyz, x.xyz);
                theta += _Rotation * PI / 180;
                float s = sin(theta * 2) * sin(theta * 2);
                float2 uv = float2(birefresence * 10, s);
                float edge_value = EdgeValue(i.position, light_dir);
                float4 open_color = tex2D(_OpenNicolTex, i.position);
                return (tex2D(_MainTex, uv) * _CrossNicol + float4(edge_value, edge_value, edge_value, 1) * (1 - _CrossNicol)) * open_color;
            }

            ENDCG
        }
    }
    Fallback "Transparent/Diffuse"
}
