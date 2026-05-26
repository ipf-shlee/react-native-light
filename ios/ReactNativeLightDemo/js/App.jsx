import { h, render, useState, View, Text, Pressable } from '../../../js/react-light.js';

function Button({ label, color, onPress }) {
  return (
    <Pressable
      backgroundColor={color}
      width={60}
      height={50}
      justifyContent="center"
      alignItems="center"
      onPress={onPress}
    >
      <Text fontSize={28} color="#ffffff">
        {label}
      </Text>
    </Pressable>
  );
}

function App() {
  const [count, setCount] = useState(0);

  // Text 양옆에 -/+ 버튼 — onPress가 setState 트리거 → 재렌더의 full cycle.
  // 하단은 여전히 파란 placeholder, 다음 commit에서 ScrollView + history로 교체.
  return (
    <View flex={1} padding={16} gap={16}>
      <View flexDirection="row" justifyContent="center" alignItems="center" gap={16}>
        <Button color="#ff3333" label="-" onPress={() => setCount(count - 1)} />
        <Text width={80} textAlign="center" fontSize={48} color="#000000">
          {count}
        </Text>
        <Button color="#0066ff" label="+" onPress={() => setCount(count + 1)} />
      </View>
      <View flex={1} backgroundColor="#0066ff" />
    </View>
  );
}

render(<App />);
