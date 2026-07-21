Mod Button - Next to close and red.
    It will change the menu to show the red - buttons and undo button.
    Red and undo are hidden until mod is clicked, and hidden again when mod is clicked again.

Multi pose furniture, like benches.
    At the bottom of Pose menu we will list pose numbers horizontally. Each animation will keep the original 1 pose number to use, thats the pose the player is moved into.
    Clicking another pose number moves the player to those coords, does not edit json.
    If no poses use a pose number, then admins can remove that pose number. What we will do is pose numbers will shift up, and a red minus sign will appear below poses that can be removed. If a pose number cant be removed then we will have empty space to keep things looking organized.
        - When a pose number is removed or saved over, it is cached as an old number and numbered 1+ in order.
        - In the undo menu these old numbers will be listed on the left hand side. With a green + and red minus. Green + adds to the 4 shown numbers if space is available, red - deletes the pose from the undo cache.
        - For poses we will add a red minus to the undo cache as well so admins can remove it if they want to. This would then allow players to add it back.
    Moodify pose - modify pose lets players change pose numbers on poses or make a new pose number.
        - If pose numbers exist, list at bottom for players to select to use for pose as another option.
        - If a pose number is not in use it will show red, allowing a player to save over that number with new coords.
    Poses will show as Pose #(# all the way to the right). Players can pick a number then a pose to enter. picking a pose uses its cached number.
    Pose numbers show show in a white text, turn green when selected or entered.
        - by clicking the number or entering a pose using that number.