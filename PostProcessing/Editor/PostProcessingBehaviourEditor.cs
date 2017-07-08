using System;
using System.Linq.Expressions;
using UnityEngine.PostProcessing;

namespace UnityEditor.PostProcessing
{
    [CustomEditor(typeof(PostProcessingBehaviour))]
    public class PostProcessingBehaviourEditor : Editor
    {
        SerializedProperty m_Profile;
        SerializedProperty m_Antialiasing;

        public void OnEnable()
        {
            m_Profile = FindSetting((PostProcessingBehaviour x) => x.profile);
            m_Antialiasing = FindSetting((PostProcessingBehaviour x) => x.antialiasing);
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.PropertyField(m_Profile);
            EditorGUILayout.PropertyField(m_Antialiasing, true);

            serializedObject.ApplyModifiedProperties();
        }

        SerializedProperty FindSetting<T, TValue>(Expression<Func<T, TValue>> expr)
        {
            return serializedObject.FindProperty(ReflectionUtils.GetFieldPath(expr));
        }
    }
}
