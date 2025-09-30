# 🎬 AnimSheet - Bring Your Spritesheets to Life!

✨ **Turn your sprite sheets into fully-animated sprites with just a few clicks!** ✨


![Plugin Screenshot](images/demo.png)
![Plugin Screenshot 2](images/demo2.png)

**SpriteSheet Source:** [Snoblin's Pixel RPG Free NPC](https://snoblin.itch.io/pixel-rpg-free-npc)

Say goodbye to the hassle of manually setting up Animation Player ! AnimSheet lets you **effortlessly create `Sprite2D` and `AnimationPlayer` or one `AnimatedSprite2D` nodes** directly from your sprite sheets. Just **load**, **define**, and **generate animation** – it's that easy! 🚀

---

## 🎯 Features

 **Supports Common Formats** – Load PNG, JPG, WEBP, and more!  
 **Visual Feedback** – See a **grid overlay** on your sprite sheet for easy alignment.  
 **Fast Animation Setup:**  
   - 🔍 **Auto-Detect** – Let AnimSheet find animations automatically! Works with transparent backgrounds and strips.
   - 🖱️ **Manual Drag & Drop** – Draw animation frames directly on the sprite sheet preview!
**Custom FPS Settings** – Control playback speed per animation.  
**One-Click Node Generation** – Instantly create `Sprite2D` and `AnimationPlayer` nodes with correctly set animation tracks. 

---

## 🚀 Installation

### 📦 **From Asset Library** (Recommended)
1. Open **Godot Editor** and go to the `AssetLib` tab.
2. Search for **AnimSheet**.
3. Download & install the plugin.
4. Enable it in **Project -> Project Settings -> Plugins**.

### 🔧 **Manual Installation**
1. Download the `addons/anim_sheet` folder from this repository.
2. Place the `addons` folder in your Godot project directory.
3. Enable the plugin in **Project -> Project Settings -> Plugins**.

---

## 🛠️ How to Use

 **1. Open the Plugin:**  
Go to `Project -> Tools -> Sprite Sheet Animator` in the Godot Editor.

 **2. Load Your Sprite Sheet:**  
Click the **Load Texture** button and select your sprite sheet image.

 **3. Set Frame Size:**  
Adjust **Sprite Width** and **Sprite Height** to match the size of a single frame.

 **4. Define Animations:**  
 
 **A. Auto-Detect Mode**
  - Choose the animation layout **(Horizontal or Vertical)**.
  - (Optional) Set "Frames Per Anim" to split longer strips into multiple animations.
  - Click **Auto Detect Animations** – magic happens! ✨
  
  **B. Manual Mode**
  - Click & drag to **draw rectangles** around animation frames.

**5. Fine-Tune Your Animations (Optional):**  
-  Rename: Click an animation’s name label (e.g., "Anim1") to rename it.
-  Delete: Right-click an animation's outline to remove it.

**6. Generate Nodes:**  
- Open a scene in Godot.
- Click **Generate Nodes** and watch your sprite come to life! 🎉

---

## 📜 License
This project is licensed under **MIT** – use it freely in your games! 🚀
