import { h, render, useState, View, Text } from '../../../js/react-light.js';

function App() {
  const [count] = useState(0);

  // Text 값을 useState로 연결 — 시각적으론 여전히 "0"이지만 출처가 state.
  // 재렌더 데모는 Pressable 도입 후.
  return (
    <View flex={1} padding={16} gap={16}>
      <View flexDirection="row" justifyContent="center" alignItems="center">
        <Text fontSize={48} color="#000000">{count}</Text>
      </View>
      <View flex={1} backgroundColor="#0066ff" />
    </View>
  );
}

render(<App />);
