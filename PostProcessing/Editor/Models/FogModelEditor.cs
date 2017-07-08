using UnityEngine.PostProcessing;

namespace UnityEditor.PostProcessing
{
    using Settings = FogModel.Settings;

    [PostProcessingModelEditor(typeof(FogModel))]
    public class FogModelEditor : PostProcessingModelEditor
    {
        SerializedProperty m_SkyboxBehaviour;

        public override void OnEnable()
        {
            m_SkyboxBehaviour = FindSetting((Settings x) => x.skyboxBehaviour);
        }

        public override void OnInspectorGUI()
        {
            EditorGUILayout.HelpBox("This effect adds fog compatibility to the deferred rendering path; enabling it with the forward rendering path won't have any effect. Actual fog settings should be set in the Lighting panel.", MessageType.Info);
            EditorGUILayout.PropertyField(m_SkyboxBehaviour);
            EditorGUI.indentLevel--;
        }
    }
}
