// ignore_for_file: avoid_print

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/provider/theme_provider.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingScreen extends ConsumerStatefulWidget{
  final String uid;

  const SettingScreen({super.key, required this.uid});

  @override
  // ignore: library_private_types_in_public_api
  // _SettingPageState createState() => _SettingPageState();
  ConsumerState<SettingScreen> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingScreen>{
  @override
  Widget build(BuildContext context) {
    final isLightTheme = ref.watch(themeProvider);
    final dataSaverProvider = StateProvider<bool>((ref) => true);

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: mainColor),
        title: Text(
          'Settings',
          style: AppTextStyles.title.copyWith(
            color: mainColor,
          ),
        ),
        // backgroundColor: const Color(0xFF1d3c34),
        centerTitle: true,
      ),
      body:ListView (
        children: [
          _buildSectionHeader("Appearance"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined, color: mainColor),
                    const SizedBox(width:10),
                    Text(
                      "Dark Mode",
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
                SizedBox(
                  width: 55,
                  height: 30,
                  child: AnimatedToggleSwitch<bool>.dual(
                    current: isLightTheme,
                    first:false,
                    second:true,
                    spacing:1,
                    style:ToggleStyle(
                      backgroundColor: isLightTheme ? Colors.white : Colors.grey[800],
                      borderColor: Colors.transparent,
                      boxShadow: [
                        const BoxShadow(
                          color:Colors.black26,
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                    borderWidth: 4,
                    height: 50,
                    onChanged:(b){
                      ref.read(themeProvider.notifier).state = b;
                    },
                    styleBuilder:(b) => ToggleStyle(
                      indicatorColor: !b ? Colors.blue: Colors.green,
                    ),
                    iconBuilder:(value) => value
                      ? const FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 18),
                      )
                      : const FittedBox(
                        fit: BoxFit.contain,
                        child:Icon(Icons.nightlight_round,size: 18),
                      ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("Account"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      print("Profile pressed");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(uid:widget.uid),
                        ),
                      );
                    }, 
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: mainColor),
                        const SizedBox(width:10),
                        Text(
                          "Profile",
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500 ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
           _buildSectionHeader("Mode"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.data_saver_off_outlined, color: mainColor),
                    const SizedBox(width:10),
                    Text(
                      "Data Saver",
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
                SizedBox(
                  width: 55,
                  height: 30,
                  child: AnimatedToggleSwitch<bool>.dual(
                    current: ref.watch(dataSaverProvider),
                    first:false,
                    second:true,
                    spacing:1,
                    style: const ToggleStyle(
                     
                      borderColor: Colors.transparent,
                      boxShadow: [
                        const BoxShadow(
                          color:Colors.black26,
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                    borderWidth: 4,
                    height: 50,
                    onChanged: (value) {
                      ref.read(dataSaverProvider.notifier).state = value;
                    },
                    styleBuilder:(b) => ToggleStyle(
                      indicatorColor: !b ? Colors.blue: mainColor,
                    ),
                    iconBuilder:(value) => value
                      ? const FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(Icons.data_saver_on_outlined, color: Colors.white, size: 18),
                      )
                      : const FittedBox(
                        fit: BoxFit.contain,
                        child:Icon(Icons.data_saver_off_outlined,size: 18),
                      ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height:40,
        child: Center(
          child: Text(
            'DA.17.00.A.010',
            style: AppTextStyles.caption.copyWith(
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildSectionHeader(String title){
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
      )
    );
  }

  
  
}