import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UploadImages extends StatelessWidget {
  const UploadImages({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 80,
          ),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: BouncingScrollPhysics(),
          itemCount: 6,
          itemBuilder: (context, index) {
            if (index == 0) {
              return GestureDetector(
                child: Image.asset(
                  Assets.imagesAddPhoto,
                  height: Get.height,
                  width: Get.width,
                ),
              );
            } else {
              return Image.asset(
                Assets.imagesPhotoPlaceHolder,
                height: Get.height,
                width: Get.width,
              );
            }
          },
        ),
      ],
    );
  }
}
