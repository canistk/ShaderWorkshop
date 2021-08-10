using UnityEngine;

namespace Kit
{
    [RequireComponent(typeof(Camera))]
	public class ObserverMovement : MonoBehaviour
	{
        [Header("Keyboard - Movement")]
        public bool m_WASD = true;
        public bool m_QE = true;
		public float m_Speed = 0.05f;
        public float m_HighSpeed = 0.25f;
        const float s_VerticalSpeedBias = 0.5f;

        [Header("Mouse - Movement")]
        public bool m_RightClickLook = true;
        public bool m_MiddleDrag = true;
        public bool m_ScrollZoom = true;
        public float m_ScrollSpeed = 1.25f;

        void Update()
        {
            RelativeMovement(GetMouseLook(), GetDeltaMovement(GetSpeed()));
        }

        private void RelativeMovement(Vector3 mouseLook, Vector3 deltaMovement)
        {
            transform.Translate(deltaMovement, Space.World);
            if (Cursor.lockState == CursorLockMode.Locked)
            {
                transform.Rotate(Vector3.right, mouseLook.x, Space.Self);
                transform.Rotate(Vector3.up, mouseLook.y, Space.World);
            }
        }

        Vector3 m_LastMousePos = Vector3.zero;
        private Vector3 GetDeltaMovement(float speed)
        {
            Vector3 delta = default;

            // W,A,S,D
            if (m_WASD)
            {
                float vertical = Input.GetAxis("Vertical");
                if (vertical != 0)
                {
                    delta += transform.forward * speed * vertical;
                }
                float horizontal = Input.GetAxis("Horizontal");
                if (horizontal != 0)
                {
                    delta += transform.right * speed * horizontal;
                }
            }

            // Q,E Up & Down
            if (m_QE)
            {
                bool down = Input.GetKey(KeyCode.Q);
                bool up = Input.GetKey(KeyCode.E);
                if (up && !down)
                {
                    delta += transform.up * speed * s_VerticalSpeedBias;
                }
                else if (down && !up)
                {
                    delta += -transform.up * speed * s_VerticalSpeedBias;
                }
            }


            // Mouse - Left, Right, Up, Down
            if (m_MiddleDrag)
            {
                if (Input.GetMouseButton(2))
                {
                    if (Input.GetMouseButtonDown(2))
                    {
                        // First frame reset.
                        m_LastMousePos = Input.mousePosition;
                    }
                    Vector3 diff = m_LastMousePos - Input.mousePosition;
                    delta += transform.TransformVector(diff) * speed;
                    m_LastMousePos = Input.mousePosition;
                }
            }

            // Mouse scroll wheel, forward/Backward
            if (m_ScrollZoom)
            {
                if (Input.mouseScrollDelta.y != 0f)
                    delta += transform.forward * Input.mouseScrollDelta.y * m_ScrollSpeed;
                if (Input.mouseScrollDelta.x != 0f)
                    delta += transform.right * Input.mouseScrollDelta.x * m_ScrollSpeed;
            }

            return delta;
        }

        private float GetSpeed()
        {
            return Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift) ?
                m_HighSpeed :
                m_Speed;
        }

        private Vector2 GetMouseLook()
        {
            if (!m_RightClickLook)
                return Vector2.zero;
            bool mouse1 = Input.GetMouseButton(1);
            if (mouse1 && Cursor.lockState == CursorLockMode.None)
            {
                Cursor.lockState = CursorLockMode.Locked;
            }
            else if (!mouse1 && Cursor.lockState == CursorLockMode.Locked)
            {
                Cursor.lockState = CursorLockMode.None;
            }
            
            if (Cursor.lockState == CursorLockMode.Locked)
            {
                return new Vector2(
                    -Input.GetAxis("Mouse Y"), // follow Unity style : flip Y.
                    Input.GetAxis("Mouse X"));
            }
            return Vector2.zero;
        }

    }
}